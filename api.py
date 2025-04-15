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
            scraper.session.close()


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
                all_listings[product] = listing
            if len(new_listings) != 0:
                self.session.add_all(new_listings)
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
        self.session.close()
        self.engine.dispose()

        print("Session closed and engine disposed.")



if __name__ == "__main__":
    api = API()
    asyncio.run(api.scrape_all())