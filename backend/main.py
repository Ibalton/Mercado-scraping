from fastapi import FastAPI, HTTPException,Query
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from api import API
from pydantic import BaseModel
from contextlib import asynccontextmanager
import asyncio
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("main")

api = API()

app = FastAPI()


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Or ["http://localhost:3000"]
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

tasks = []


class QueryRequest(BaseModel):
    query_text: str
    client_id: int
    frequency: str
    pages_to_scrape: int

@app.get("/health")
async def health_check():
    logger.info("🏥 Health check endpoint called")
    health_status = {"status": "healthy", "message": "Service is running"}
    logger.info(f"🏥 Health check response: {health_status}")
    return health_status

@app.get("/")
async def hello_world():
    return {"message": "Hello, World!"}

@app.get('/query')
async def get_queries(client_id:int = Query(None),client_email:str = Query(None)):
    queries = api.get_queries(client_id=client_id, client_email=client_email)
    return queries
@app.get('/query/results')
async def get_query_results(query_id:int = Query(None)):
    results = api.get_query_results(query_id=query_id)
    return results
@app.post("/query")
async def create_query(body: QueryRequest):
    logger.info(f"Creating query: {body}")
    # Placeholder for query creation logic
    # Replace with actual query creation logic
    try:
        query = api.post_query(body.query_text, body.client_id, body.frequency, body.pages_to_scrape)
        logger.info("Query created successfully")
        return {"message": "Query created successfully", "query": query}
    except Exception as e:
        logger.error(f"Error creating query: {str(e)}")
        return {"error": str(e)}
    
class ClientRequest(BaseModel):
    client_name: str
    client_email: str
@app.get("/client")
async def get_all_clients():
    """
    Get all clients
    """
    try:
        clients = api.get_all_clients()
        return clients
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/client")
async def create_client(body: ClientRequest):
    try:
        client = api.create_client(body.client_name, body.client_email)
        return {"message": "Client created successfully","client": client}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
#TODO: allow specific query scrapes or user specific query scrapes
@app.post("/trigger-scrape")
async def trigger_scrape():
    if tasks:
        logger.info("Scrape already in progress")
        return {"message": "Scrape already in progress"}
    logger.info("Triggering scrape")
    task = asyncio.create_task(api.scrape_all())
    task.add_done_callback(lambda t: tasks.pop() if tasks else None)
    tasks.append(task)
    logger.info("Scrape triggered successfully")
    return {"message": "Scrape triggered successfully"}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

