import asyncio
import boto3
import json
import os
import pandas as pd
from sentence_transformers import SentenceTransformer
from sqlalchemy import create_engine, text
import logging
from sqlalchemy.orm import sessionmaker
from functions import Database

from base.mercadolibre import MercadoLibre  # Replace with actual import
from botocore.config import Config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("scraper")
# Set up boto3 SQS client
sqs = boto3.client(
    "sqs",
    region_name="us-east-1",  # change as needed
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

        # (Optional) Upload or further processing
        print(df.head())

    except Exception as e:
        print(f"Error handling message: {e}")

async def poll_sqs():
    while True:
        response = sqs.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=20  # Long polling
        )

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
