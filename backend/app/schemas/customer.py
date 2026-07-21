from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class CustomerCreate(BaseModel):

    full_name: str

    mobile: str = Field(
        min_length=10,
        max_length=10,
        pattern=r"^\d{10}$",
    )

    alternate_mobile: str | None = Field(
        default=None,
        min_length=10,
        max_length=10,
        pattern=r"^\d{10}$",
    )

    email: EmailStr | None = None

    address: str | None = None

    city: str | None = None

    pincode: str | None = None



class CustomerResponse(BaseModel):

    id: int

    customer_code: str

    full_name: str

    mobile: str

    alternate_mobile: str | None

    email: str | None

    address: str | None

    city: str | None

    pincode: str | None

    status: str

    created_at: datetime


    class Config:

        from_attributes = True
