from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncio
import logging
import json
from typing import Dict

from botocore.config import Config
import boto3
import os

from sqs_runner import handle_message  # Re-use existing async logic
from database import Database  # Shared DB helper
from models import ClientQueries

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("scraper-api")

app = FastAPI()


class ScrapeRunRequest(BaseModel):
    queries: Dict[str, int]


@app.get("/scrape/health")
async def health_check():
    return {"status": "healthy"}


@app.post("/scrape/run")
async def scrape_run(body: ScrapeRunRequest):
    """Run a scrape immediately for the supplied queries."""
    try:
        await handle_message({"queries": body.queries})
        return {"status": "ok", "queries": body.queries}
    except Exception as e:
        logger.error("scrape_run failed: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


# Optional: reuse SQS to keep existing architecture
USE_SQS = os.getenv("USE_SQS", "false").lower() == "true"
if USE_SQS:
    SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")
    SQS_REGION = os.getenv("SQS_REGION")
    sqs_client = boto3.client(
        "sqs",
        region_name=SQS_REGION,
        config=Config(retries={"max_attempts": 3})
    )


@app.post("/scrape/schedule-from-db")
async def schedule_from_db():
    """Read client_queries table and schedule scrapes via SQS or locally."""
    try:
        db = Database()
        products = db.session.query(ClientQueries).all()
        queries: Dict[str, int] = {}
        for prod in products:
            qtext = prod.query.query_text
            pages = prod.pages_to_scrape
            if qtext in queries and pages <= queries[qtext]:
                continue
            queries[qtext] = pages

        logger.info("Built %d queries from DB", len(queries))

        if USE_SQS and SQS_QUEUE_URL:
            # Maintain previous behaviour – push each query onto SQS
            for qtext, pages in queries.items():
                message_body = json.dumps({"query": qtext, "pages_to_scrape": pages})
                sqs_client.send_message(
                    QueueUrl=SQS_QUEUE_URL,
                    MessageBody=message_body,
                    MessageGroupId="default",
                    MessageDeduplicationId=qtext  # idempotent per query
                )
            return {"status": "queued", "count": len(queries)}
        else:
            # Directly invoke the scrape in-process for each chunk
            await handle_message({"queries": queries})
            return {"status": "scraped", "count": len(queries)}
    except Exception as e:
        logger.error("schedule-from-db failed: %s", e)
        raise HTTPException(status_code=500, detail=str(e)) 