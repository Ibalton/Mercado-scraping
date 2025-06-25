from fastapi import FastAPI, HTTPException,Query, Depends, Request, Response
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from api import API
from pydantic import BaseModel
from contextlib import asynccontextmanager
import asyncio
import logging
from api_gateway import trigger_global_scrape
from auth import login as cognito_login, auth_callback, admin_required, authenticated_user, logout as logout_handler

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("main")

api = API()

app = FastAPI()


app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",  # Frontend development server
        "http://localhost:3000",  # Alternative React dev server
        "http://127.0.0.1:5173",  # Alternative localhost
    ],
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

@app.get("/api/health")
async def health_check():
    logger.info("🏥 Health check endpoint called")
    health_status = {"status": "healthy", "message": "Service is running"}
    logger.info(f"🏥 Health check response: {health_status}")
    return health_status

@app.get("/api/")
async def hello_world():
    return {"message": "Hello, World!"}

@app.get("/api/login")
async def login_route(request: Request):
    return await cognito_login(request)

app.add_api_route("/api/auth/callback", auth_callback, methods=["GET"], name="auth_callback")

@app.post("/api/logout")
async def logout_route(response: Response):
    return await logout_handler(response)

# Work-in-progress endpoint for non-admin authenticated users
@app.get("/api/wip", dependencies=[Depends(authenticated_user)])
async def wip():
    return {"message": "🚧 Work in progress"}

# Identify current user (used by SPA AuthProvider)
@app.get("/api/me")
async def me(user=Depends(authenticated_user)):
    return user

# Protect admin routes
@app.get('/api/query', dependencies=[Depends(admin_required)])
async def get_queries(client_id:int = Query(None),client_email:str = Query(None)):
    queries = api.get_queries(client_id=client_id, client_email=client_email)
    return queries

@app.get('/api/query/results', dependencies=[Depends(admin_required)])
async def get_query_results(query_id:int = Query(None)):
    results = api.get_query_results(query_id=query_id)
    return results

@app.post("/api/query", dependencies=[Depends(admin_required)])
async def create_query(body: QueryRequest):
    logger.info(f"Creating query: {body}")
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

@app.get("/api/client", dependencies=[Depends(admin_required)])
async def get_all_clients():
    """
    Get all clients
    """
    try:
        clients = api.get_all_clients()
        return clients
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/client", dependencies=[Depends(admin_required)])
async def create_client(body: ClientRequest):
    try:
        client = api.create_client(body.client_name, body.client_email)
        return {"message": "Client created successfully","client": client}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/trigger-scrape", dependencies=[Depends(admin_required)])
async def trigger_scrape():
    """Proxy endpoint that asks the scraper service to perform a global scrape."""
    try:
        # Run the blocking HTTP call in a thread so we do not block the asyncio loop
        response = await asyncio.to_thread(trigger_global_scrape)
        return response
    except Exception as e:
        logger.error("Error triggering scrape via scraper service: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

