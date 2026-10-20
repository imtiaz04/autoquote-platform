from fastapi import FastAPI

from app.routes.quotes import router as quotes_router


app = FastAPI(
    title="AutoQuote Insurance Comparison API",
    version="1.0.0"
)


@app.get("/")
def home():
    return {
        "message": "Welcome to AutoQuote Insurance Comparison API"
    }


app.include_router(quotes_router)
