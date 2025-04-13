from models import *

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sentence_transformers import SentenceTransformer
from base.mercadolibre import MercadoLibre
from sqlalchemy import select
# Create a database engine
class API():
    def __init__(self):
        self.engine = create_engine('postgresql://postgres:secret@localhost:5431/postgres')
        self.session = sessionmaker(bind=self.engine)()
        self.model = SentenceTransformer('all-MiniLM-L6-v2')
    async def scrape_all(self):
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
        for product in merca.data.itertuples(index=False):
            product = merca.data.iloc[0]
            product_abs = self.find_nearest_title(product)
            if product_abs:
                product_abs = product_abs[0]
                if product_abs.distance <0.5:
                    product_abs = self.session.query(Products).filter(Products.id == product_abs.id).first()
                else:
                    del product_abs
            if not product_abs:
                product_abs = Products(
                    name = product.title,
                )
                self.session.add(product_abs)
                self.session.commit()

            listing = self.find_listing_by_ml_id(product)
            if not listing:
                listing = Listings(
                    external_id = product.ml_id,
                    title = product.title,
                    url = product.url,
                    marketplace_id = 1,
                    product_id = product_abs.id,
                )
                self.session.add(listing)
                self.session.commit()
            else:
                listing = listing[0]

            price = Prices(
                listing_id = listing.id,
                price = product.price
            )
            self.session.add(price)
            self.session.commit()

    def find_listing_by_ml_id(self,product):
        self.session.query(Listings).filter(Listings.external_id == product.ml_id , Listings.marketplace_id == 1).all()
    def find_nearest_title(self,product):
        query_vector  = self.model.encode(product.title)

        stmt = (
            select(
                ProductEmbeddings,
                ProductEmbeddings.embedding.op('<->')(query_vector).label("distance")
            )
            .order_by("distance")
            .limit(5)
        )
        return self.session.execute(stmt).all()





