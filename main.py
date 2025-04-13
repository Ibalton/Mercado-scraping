from fastapi import FastAPI
import uvicorn

app = FastAPI()

@app.get("/")
async def hello_world():
    return {"message": "Hello, World!"}

@app.post("/trigger-scrape")
async def trigger_scrape():
    # Placeholder for scrape logic
    # Replace with actual scraping function
    return {"message": "Scrape triggered successfully"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=80, reload=True)

