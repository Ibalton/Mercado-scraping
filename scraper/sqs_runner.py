import asyncio
import boto3
import json
import os
import pandas as pd
from sentence_transformers import SentenceTransformer
from sqlalchemy import create_engine, text
import logging
from sqlalchemy.orm import sessionmaker
from database import Database
from models import Listings, Prices, ProductCandidates, ProductEmbeddings, Products
from base.mercadolibre import MercadoLibre  # Replace with actual import
from botocore.config import Config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("scraper")
# Set up boto3 SQS client
sqs = boto3.client(
    "sqs",
    region_name=os.getenv("SQS_REGION"),  # change as needed
    config=Config(retries={"max_attempts": 3})
)
database = Database()
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")  # or hardcode it here

# Initialize SentenceTransformer model once globally (avoid reloading each time)
model = SentenceTransformer('all-MiniLM-L6-v2')

async def handle_message(message_body):
    """Parse SQS message and run MercadoLibre scraper, vectorize 'title' column"""
    try:
        data = json.loads(message_body)
        queries = data.get("queries", {})
        scraper = MercadoLibre(queries=queries)

        df = await scraper.perform_scrape()

        # Check if 'title' column exists
        if "title" in df.columns:
            titles = df["title"].astype(str).tolist()  # Ensure all titles are strings
            embeddings = model.encode(titles, show_progress_bar=False)

            # Add embeddings as a new column (list of floats)
            df["title_vector"] = list(embeddings)
        else:
            print("Warning: 'title' column not found in scraped DataFrame.")

        await load_to_db(df)

    except Exception as e:
        print(f"Error handling message: {e}")


async def load_to_db(df:pd.DataFrame):
    all_new_products = []
    all_products = []
    all_product_embeddings = []
    new_candidates = []
    new_listings = []
    all_listings = {}
    safe_commit_flag = False
    query_list = []
    query_text:str
    for query_text in df["query"]:
        query_list.extend(query_text.split("-QUERYSEP-"))
    queries_objs = database.retrieve_queries(queries=query_list)
    queries_map = {q.query_text: q for q in queries_objs}

    for product in df.itertuples(index=False):
        nearest_product = database.find_nearest_title(product)
        if nearest_product and nearest_product.distance < 0.15:
            nearest_product = database.session.query(Products).filter(Products.id == nearest_product.product_id).first()
        else:
            nearest_product = Products(
                name = product.title,
            )
            all_new_products.append(nearest_product)
        all_products.append(nearest_product)
                
            
    if len(all_new_products) != 0:
        database.session.add_all(all_new_products)
        database.safe_commit() 
    for product in all_new_products:
        emb = ProductEmbeddings(
            product_id = product.id,
            embedding = list(map(float,database.model.encode(product.name, normalize_embeddings=True)))
        )
        all_product_embeddings.append(emb)
    if len(all_product_embeddings) != 0:
        database.session.add_all(all_product_embeddings)
        database.safe_commit()

    for i, prod in enumerate(df.itertuples(index=False)):
        listing = database.find_listing_by_ml_id(prod)
        if not listing:
            try:
                distance = all_products[i].distance
            except Exception:
                distance = 0.0
            listing = Listings(
                external_id=prod.ml_id,
                title=prod.title,
                url=prod.url,
                marketplace_id=1,
                img_url=prod.img_url
            )
            new_listings.append(listing)

            for query_text in prod.query.split("-QUERYSEP-"):
                if query_text not in queries_map:
                    continue
                query_obj = queries_map[query_text]
                candidate = ProductCandidates(
                    query_id=query_obj.id,
                    product_id=all_products[i].id,
                    match_method='cosine',
                    distance=distance,
                    decided=False,
                    listing=listing
                )
                new_candidates.append(candidate)
        elif listing.img_url != prod.img_url:
            listing.img_url = prod.img_url
            safe_commit_flag = True
        all_listings[prod] = listing
    if new_listings:
        database.session.add_all(new_listings)
        safe_commit_flag = True
    if safe_commit_flag:
        database.safe_commit()

    for candidate in new_candidates:
        candidate.listing_id = candidate.listing.id
    if new_candidates:
        database.session.add_all(new_candidates)
        database.safe_commit()

    all_prices = []
    for prod, listing in all_listings.items():
        price = Prices(
            listing_id=listing.id,
            price=float(prod.price)
        )
        all_prices.append(price)
    database.session.add_all(all_prices)
    database.safe_commit()
    

async def poll_sqs():
    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20  # Long polling
            )
        except Exception as e:
            logger.error(f"Error polling SQS: {e}")
            await asyncio.sleep(5)  # Wait before retrying
            continue

        messages = response.get("Messages", [])
        if not messages:
            continue

        for msg in messages:
            receipt_handle = msg["ReceiptHandle"]
            body = msg["Body"]

            await handle_message(body)

            # Delete message from queue after processing
            sqs.delete_message(QueueUrl=SQS_QUEUE_URL, ReceiptHandle=receipt_handle)

if __name__ == "__main__":
    asyncio.run(poll_sqs())
