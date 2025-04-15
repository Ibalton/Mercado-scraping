import asyncio
from models import *

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sentence_transformers import SentenceTransformer
from base.mercadolibre import MercadoLibre
from sqlalchemy import select
from sqlalchemy.exc import PendingRollbackError

# Create a database engine
class API():
    def __init__(self):
        self.engine = create_engine('postgresql://postgres:secret@localhost:5431/postgres')
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

    def get_queries(self, client_id=None):
        queries = self.session.query(Queries)

        if client_id:
            # Join with ClientQueries to include additional fields
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
    
    def create_client(self, client_name: str, client_email: str):
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
            return client
        except Exception as e:
            self.session.rollback()
            raise e

    def post_query(self, query_text, client_id, frequency, pages_to_scrape):
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
            products = self.session.query(ClientQueries).all()
            queries = {}
            # Print the fetched products
            for product in products:
                if product.query.query_text in queries:
                    if product.pages_to_scrape > queries[product.query.query_text]:
                        queries[product.query.query_text] = product.pages_to_scrape
                else:
                    queries[product.query.query_text] = product.pages_to_scrape
            merca = MercadoLibre(queries=queries)
            await merca.scrape()

            #For every product in the scraped data 
            for product in merca.data.itertuples(index=False):
                product_abs = self.find_nearest_title(product)
                if product_abs:
                    product_abs = product_abs[0]
                    if product_abs.distance <0.75:
                        product_abs = self.session.query(Products).filter(Products.id == product_abs.product_id).first()
                    else:
                        product_abs = None
                if not product_abs:
                    product_abs = Products(
                        name = product.title,
                    )
                    self.session.add(product_abs)
                    self.safe_commit()  # Use safe_commit to handle rollback
                    emb = ProductEmbeddings(
                        product_id = product_abs.id,
                        embedding = list(map(float,self.model.encode(product.title, normalize_embeddings=True)))
                    )
                    self.session.add(emb)
                    self.safe_commit()  # Use safe_commit to handle rollback
                

                

                listing = self.find_listing_by_ml_id(product)
                if not listing:
                   
                    try:
                        distance = product_abs.distance
                    except:
                        distance = 0.0
                    candidate = ProductCandidates(
                        query_id = self.session.query(Queries).filter(Queries.query_text == product.query).first().id,
                        product_id = product_abs.id,
                        match_method = 'nearest',
                        distance = distance,
                        decided = False
                    
                    )
                    self.session.add(candidate)
                    self.safe_commit()
                    

                    listing = Listings(
                        external_id = product.ml_id,
                        title = product.title,
                        url = product.url,
                        marketplace_id = 1,
                        candidate_id = candidate.id,
                    )
                    self.session.add(listing)
                    self.safe_commit()  # Use safe_commit to handle rollback
                else:
                    listing = listing[0]

                price = Prices(
                    listing_id = listing.id,
                    price = float(product.price)
                )
                self.session.add(price)
                self.safe_commit()  # Use safe_commit to handle rollback
        except Exception as e:
            self.session.rollback()
            raise e

    def find_listing_by_ml_id(self,product):
        return self.session.query(Listings).filter(Listings.external_id == product.ml_id , Listings.marketplace_id == 1).all()
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
                embedding <-> '[{query_vector_str}]'::vector AS distance
            FROM 
                product_embeddings
            ORDER BY 
                distance
            LIMIT 5;
        """)
        return self.session.execute(raw_query).all()
    def __del__(self):
        # rollback any uncommitted transactions
        try:
            self.session.rollback()
        except Exception as e:
            print(f"Error during rollback: {e}")
        # Close the session and dispose of the engine
        self.session.close()
        self.engine.dispose()

        print("Session closed and engine disposed.")



if __name__ == "__main__":
    api = API()
    asyncio.run(api.scrape_all())