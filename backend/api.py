import asyncio
from models import *

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sentence_transformers import SentenceTransformer
from base.mercadolibre import MercadoLibre
from sqlalchemy import select
from sqlalchemy.exc import PendingRollbackError
import os

from dotenv import load_dotenv
import os
from sqlalchemy.orm import class_mapper

def serialize_model(model):
    """
    Serialize a SQLAlchemy model instance into a dictionary.
    """
    columns = [column.key for column in class_mapper(model.__class__).columns]
    return {column: getattr(model, column) for column in columns}
# Create a database engine
class API():
    def __init__(self):
        DATABASE_URL = "postgresql+psycopg2://postgres:secret@localhost:5431/postgres"  # ✅ should be using env var
        print(DATABASE_URL)
        self.engine = create_engine(DATABASE_URL)
        self.session = sessionmaker(bind=self.engine)()
        self.model = SentenceTransformer('all-MiniLM-L6-v2')

    def safe_commit(self):
        """
        Safely commit the session, handling PendingRollbackError.
        """
        try:
            self.session.commit()
        except PendingRollbackError:
            self.session.rollback()
            raise Exception("Transaction failed and was rolled back.")
    def get_query_results(self, query_id:int):
        query = text(f"""
        SELECT l.id,l.external_id,l.title,l.url,p.price,p.scraped_at,pro.name,pro.created_at,l.img_url,
                     l.created_at,l.last_seen
        FROM product_candidates pc
        INNER JOIN products pro ON pc.product_id = pro.id
        INNER JOIN listings l ON pc.listing_id = l.id
        INNER JOIN prices p ON l.id = p.listing_id
        WHERE pc.query_id = {query_id}
        """)
        try:
            result = self.session.execute(query).fetchall()
            # Convert the result to a list of dictionaries
            products = dict()

            for row in result:
                product_id = row[6]
                if product_id in products:
                    listings = products[product_id]["listings"]
                else:
                    products[product_id] = {
                        "id": product_id,
                        "name": row[7],
                        "listings": dict()
                    }
                    listings = products[product_id]["listings"]
                
                if row[0] in listings:
                    listings[row[0]]["prices"].append({"price": row[4], "created_at": row[5]})
                else:
                    listing = {
                        "id": row[0],
                        "external_id": row[1],
                        "title": row[2],
                        "url": row[3],
                        "img_url": row[8],	
                        "created_at": row[9],
                        "last_seen": row[10],
                        "prices":[
                            {"price": row[4], "created_at": row[5]}
                        ]
                    }
                    listings[row[0]] = listing
            for key in products:
                products[key]["listings"] = list(products[key]["listings"].values())
            return list(products.values())
                    
        except Exception as e:
            self.session.rollback()
            raise e

    def get_queries(self, client_id=None,client_email=None):
        queries = self.session.query(Queries)

        if client_id or client_email:
            # Join with ClientQueries to include additional fields
            if client_id:
                queries = (
                    queries.join(ClientQueries)
                    .filter(ClientQueries.client_id == client_id)
                    .with_entities(
                        Queries.query_text,
                        ClientQueries.pages_to_scrape,
                        ClientQueries.frequency,
                        Queries.created_at,
                        Queries.removed_at
                    )
                )
            else:
                queries = (
                    queries.join(ClientQueries.Client)
                    .filter(Clients.email == client_email)
                    .with_entities(
                        Queries.query_text,
                        ClientQueries.pages_to_scrape,
                        ClientQueries.frequency,
                        Queries.created_at,
                        Queries.removed_at
                    )
                )
            # Convert the result to a list of dictionaries
            result = [
                {
                    "query_text": query_text,
                    "pages_to_scrape": pages_to_scrape,
                    "frequency": frequency,
                    "created_at": created_at,
                    "removed_at": removed_at
                }
                for query_text, pages_to_scrape, frequency,created_at,removed_at in queries.all()
            ]
        else:
            # If no client_id is provided, return only the query text
            queries = queries.with_entities(Queries.query_text,
                                            Queries.created_at,
                                            Queries.removed_at)
            # Convert the result to a list of dictionaries
            result = [{"query_text": query_text,
                       "created_at": created_at,
                    "removed_at": removed_at } for query_text,created_at,removed_at in queries.all()]

        return result
    
    def create_client(self, client_name: str, client_email: str)->dict:
        try:
            client = self.session.query(Clients).filter(Clients.email == client_email).first()
            if not client:
                client = Clients(
                    name=client_name,
                    email=client_email
                )
                self.session.add(client)
                self.safe_commit()  # Use safe_commit to handle rollback
            else:
                raise Exception('Client already exists')
            return serialize_model(client)
        except Exception as e:
            self.session.rollback()
            raise e

    def post_query(self, query_text, client_id, frequency, pages_to_scrape)-> ClientQueries:
        try:
            query = self.session.query(Queries).filter(Queries.query_text == query_text).first()
            if not query:
                query = Queries(
                    query_text=query_text
                )
                self.session.add(query)
                self.safe_commit()  # Use safe_commit to handle rollback

            client_query = self.session.query(ClientQueries).filter(
                ClientQueries.client_id == client_id,
                ClientQueries.query_id == query.id
            ).first()
            if client_query:
                raise Exception('Query already exists')
            client_query = ClientQueries(
                client_id=client_id,
                query_id=query.id,
                frequency=frequency,
                pages_to_scrape=pages_to_scrape
            )
            self.session.add(client_query)
            self.safe_commit()  # Use safe_commit to handle rollback
            return client_query
        except Exception as e:
            self.session.rollback()
            raise e
       
    async def get_listings(self, client_id:int):
        # Fetch the queries for the given client_id

        f"""
        SELECT * FROM client_queries cq
        INNER JOIN queries q 
        WHERE client_id = {client_id}
        
        """
        queries = self.session.query(ClientQueries).filter(ClientQueries.client_id == client_id).all()
        if not queries:
            return {"error": "No queries found for the given client_id"}
        
        # Create a dictionary to hold the listings for each query
        listings_dict = {}
        
        # Iterate through each query and fetch the corresponding listings
        for client_query in queries:
            query = self.session.query(Queries).filter(Queries.id == client_query.query_id).first()
            if query:
                listings = self.session.query(Listings).filter(Listings.external_id == query.query_text).all()
                listings_dict[query.query_text] = [listing.title for listing in listings]
        
        return listings_dict
        
    async def scrape_all(self):
        try:
            all_new_products = []
            all_products = []
            all_product_embeddings = []

            products = self.session.query(ClientQueries).all()
            queries = {}
            # Print the fetched products
            for product in products:
                if product.query.query_text in queries:
                    if product.pages_to_scrape > queries[product.query.query_text]:
                        queries[product.query.query_text] = product.pages_to_scrape
                else:
                    queries[product.query.query_text] = product.pages_to_scrape

            scraper = MercadoLibre(queries=queries)
            await scraper.scrape()
            await scraper.session.close()


            for product in scraper.data.itertuples(index=False):
                nearest_product = self.find_nearest_title(product)
                if nearest_product and nearest_product.distance < 0.15:
                    nearest_product = self.session.query(Products).filter(Products.id == nearest_product.product_id).first()
                else:
                    nearest_product = Products(
                        name = product.title,
                    )
                    all_new_products.append(nearest_product)
                all_products.append(nearest_product)
                        
                    
            if len(all_new_products) != 0:
                self.session.add_all(all_new_products)
                self.safe_commit() 
            for product in all_new_products:
                emb = ProductEmbeddings(
                    product_id = product.id,
                    embedding = list(map(float,self.model.encode(product.name, normalize_embeddings=True)))
                )
                all_product_embeddings.append(emb)
            if len(all_product_embeddings) != 0:
                self.session.add_all(all_product_embeddings)
                self.safe_commit()

            queries = self.session.query(Queries).filter(Queries.query_text.in_(queries.keys())).all()
            queries = {query.query_text: query for query in queries}
            new_candidates = []
            new_listings = []
            all_listings = {}
            safe_commit = False
            for i,product in enumerate(scraper.data.itertuples(index=False)):
                listing = self.find_listing_by_ml_id(product)
                if not listing:
                    try:
                        distance = all_products[i].distance
                    except:
                        distance = 0.0
                    listing = Listings(
                        external_id = product.ml_id,
                        title = product.title,
                        url = product.url,
                        marketplace_id = 1,
                        img_url = product.img_url
                    )
                    new_listings.append(listing)
                    
                    for query in product.query.split("-QUERYSEP-"):
                        if query not in queries:
                            continue
                        query = queries[query]
                        candidate = ProductCandidates(
                            query_id = query.id,
                            product_id = all_products[i].id,
                            match_method = 'cosine',
                            distance = distance,
                            decided = False,
                            listing = listing
                        )
                        new_candidates.append(candidate)
                elif listing.img_url != product.img_url:
                    listing.img_url = product.img_url
                    safe_commit = True
                all_listings[product] = listing
            if len(new_listings) != 0:
                self.session.add_all(new_listings)
                safe_commit = True
            if safe_commit:
                self.safe_commit()
            
            for candidate in new_candidates:    
                candidate.listing_id = candidate.listing.id
            if len(new_candidates) != 0:
                self.session.add_all(new_candidates)
                self.safe_commit()

            all_prices = []
            for product,listing in all_listings.items():
                price = Prices(
                    listing_id = listing.id,
                    price = float(product.price)
                )
                all_prices.append(price)
            self.session.add_all(all_prices)
            self.safe_commit()  # Use safe_commit to handle rollback
        except Exception as e:
            self.session.rollback()
            raise e

    def find_listing_by_ml_id(self,product):
        return self.session.query(Listings).filter(Listings.external_id == product.ml_id , Listings.marketplace_id == 1).first()
    def find_nearest_title(self,product):
        # Encode the product title into a vector
        query_vector = self.model.encode(product.title, normalize_embeddings=True)
        query_vector = list(map(float, query_vector))  # Ensure it's a list of floats

        # Convert the query vector into a PostgreSQL-compatible array and cast it to 'vector'
        query_vector_str = ','.join(map(str, query_vector))

        # Raw SQL query
        raw_query = text(f"""
                        SELECT 
                            product_id, 
                            embedding, 
                            embedding <=> '[{query_vector_str}]'::vector AS distance  -- Using <=> for HNSW search
                        FROM 
                            product_embeddings
                        ORDER BY 
                            distance  -- Orders by closest match
                        LIMIT 5;    -- Limits the results to the top 5 closest matches
                    """)
        return self.session.execute(raw_query).first()
    def __del__(self):
        # rollback any uncommitted transactions
        try:
            self.session.rollback()
        except Exception as e:
            print(f"Error during rollback: {e}")
        # Close the session and dispose of the engine
        try:
            self.session.close()
            self.engine.dispose()
        except Exception as e:
            print(f"Error during session close: {e}")

        print("Session closed and engine disposed.")



if __name__ == "__main__":
    api = API()
    asyncio.run(api.scrape_all())
