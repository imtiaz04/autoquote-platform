from datetime import date
from typing import Literal

from pydantic import BaseModel, Field


class QuoteRequest(BaseModel):

    driver_age: int = Field(
        ge=18,
        le=100,
        description="Driver age between 18 and 100"
    )

    zip_code: str = Field(
        pattern=r"^\d{5}$",
        description="Five-digit US ZIP code"
    )

    vehicle_year: int = Field(
        ge=1980,
        le=date.today().year + 1
    )

    vehicle_make: str = Field(
        min_length=1
    )

    vehicle_model: str = Field(
        min_length=1
    )

    coverage_type: Literal[
        "liability",
        "full"
    ]