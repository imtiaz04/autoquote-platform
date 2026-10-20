from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_compare_quotes_success():

    payload = {
        "driver_age": 30,
        "zip_code": "08830",
        "vehicle_year": 2022,
        "vehicle_make": "Toyota",
        "vehicle_model": "Camry",
        "coverage_type": "full"
    }

    response = client.post(
        "/quotes/compare",
        json=payload
    )

    assert response.status_code == 200

    data = response.json()

    assert data["quote_type"] == "simulated"
    assert data["currency"] == "USD"
    assert len(data["quotes"]) == 3

    assert data["quotes"][0]["provider"] == "Demo Insurer C"
    assert data["quotes"][0]["monthly_premium"] == 180.0

    assert data["quotes"][1]["monthly_premium"] == 200.0
    assert data["quotes"][2]["monthly_premium"] == 230.0
# for invalid inputs, we expect a 422 Unprocessable Entity response from FastAPI, which indicates that the request data did not pass validation.
def test_invalid_driver_age():

    payload = {
        "driver_age": 15,
        "zip_code": "08830",
        "vehicle_year": 2022,
        "vehicle_make": "Toyota",
        "vehicle_model": "Camry",
        "coverage_type": "full"
    }

    response = client.post("/quotes/compare", json=payload)

    assert response.status_code == 422


def test_invalid_zip_code():

    payload = {
        "driver_age": 30,
        "zip_code": "ABCDE",
        "vehicle_year": 2022,
        "vehicle_make": "Toyota",
        "vehicle_model": "Camry",
        "coverage_type": "full"
    }

    response = client.post("/quotes/compare", json=payload)

    assert response.status_code == 422


def test_invalid_coverage_type():

    payload = {
        "driver_age": 30,
        "zip_code": "08830",
        "vehicle_year": 2022,
        "vehicle_make": "Toyota",
        "vehicle_model": "Camry",
        "coverage_type": "premium"
    }

    response = client.post("/quotes/compare", json=payload)

    assert response.status_code == 422
