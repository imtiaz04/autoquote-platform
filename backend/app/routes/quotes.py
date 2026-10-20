from fastapi import APIRouter

from app.models.quote import QuoteRequest
from app.services.quote_service import calculate_quotes


router = APIRouter(
    prefix="/quotes",
    tags=["Insurance Quotes"]
)


@router.post("/compare")
def compare_quotes(request: QuoteRequest):
    return calculate_quotes(request)