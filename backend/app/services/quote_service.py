from datetime import date

from app.models.quote import QuoteRequest


def calculate_quotes(request: QuoteRequest):

    # Base monthly premium (simulation only)
    base_premium = 100.0

    # Driver age adjustment
    if request.driver_age < 25:
        base_premium += 50

    # Vehicle age adjustment
    vehicle_age = max(0, date.today().year - request.vehicle_year)

    if vehicle_age < 5:
        base_premium += 30

    # Coverage adjustment
    if request.coverage_type == "full":
        base_premium += 70

    # Fictional insurance providers
    providers = {
        "Demo Insurer A": 1.00,
        "Demo Insurer B": 1.15,
        "Demo Insurer C": 0.90
    }

    quotes = []

    for provider, multiplier in providers.items():

        monthly_premium = round(
            base_premium * multiplier, 2
        )

        quotes.append({
            "provider": provider,
            "monthly_premium": monthly_premium,
            "annual_premium": round(
                monthly_premium * 12, 2
            )
        })

    # Sort from lowest to highest premium
    quotes.sort(
        key=lambda quote: quote["monthly_premium"]
    )

    return {
        "quote_type": "simulated",
        "currency": "USD",
        "quotes": quotes
    }