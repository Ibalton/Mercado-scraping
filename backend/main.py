from fastapi import FastAPI, HTTPException,Query
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from api import API
from pydantic import BaseModel
from contextlib import asynccontextmanager
import asyncio

# Initialize API at startup
api = API()

""" @asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Starting up...")
    yield  # App runs here
    print("🔻 Shutting down...")
    global api
    del api
 """
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
    print("🏥 Health check endpoint called")
    health_status = {"status": "healthy", "message": "Service is running"}
    print(f"🏥 Health check response: {health_status}")
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
    print(body)
    # Placeholder for query creation logic
    # Replace with actual query creation logic
    try:
        query = api.post_query(body.query_text, body.client_id, body.frequency, body.pages_to_scrape)
        return {"message": "Query created successfully", "query": query}
    except Exception as e:
        return {"error": str(e)}
    
class ClientRequest(BaseModel):
    client_name: str
    client_email: str
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
        return {"message": "Scrape already in progress"}
    task = asyncio.create_task(api.scrape_all())
    task.add_done_callback(lambda t: tasks.pop() if tasks else None)
    tasks.append(task)
    return {"message": "Scrape triggered successfully"}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

