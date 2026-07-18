from datetime import datetime

from pydantic import BaseModel, Field


class TechnicianCreate(BaseModel):
    user_id: int | None = Field(
        default=None,
        gt=0,
    )

    full_name: str = Field(
        min_length=2,
        max_length=100,
    )

    mobile: str = Field(
        min_length=10,
        max_length=15,
    )

    specialization: str | None = Field(
        default=None,
        max_length=150,
    )

    experience_years: int = Field(
        default=0,
        ge=0,
        le=60,
    )


class TechnicianUpdate(BaseModel):
    user_id: int | None = Field(
        default=None,
        gt=0,
    )

    full_name: str | None = Field(
        default=None,
        min_length=2,
        max_length=100,
    )

    mobile: str | None = Field(
        default=None,
        min_length=10,
        max_length=15,
    )

    specialization: str | None = Field(
        default=None,
        max_length=150,
    )

    experience_years: int | None = Field(
        default=None,
        ge=0,
        le=60,
    )

    availability_status: str | None = Field(
        default=None,
        max_length=30,
    )

    status: str | None = Field(
        default=None,
        max_length=20,
    )


class TechnicianResponse(BaseModel):
    id: int
    technician_code: str
    user_id: int | None
    full_name: str
    mobile: str
    specialization: str | None
    experience_years: int
    availability_status: str
    status: str
    created_at: datetime

    model_config = {
        "from_attributes": True
    }
