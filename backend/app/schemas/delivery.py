from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class DeliveryCreate(BaseModel):
    recipient_type: Literal[
        "CUSTOMER",
        "OTHER",
    ]

    receiver_name: str | None = Field(
        default=None,
        min_length=2,
        max_length=100,
    )

    relation_to_customer: str | None = Field(
        default=None,
        min_length=2,
        max_length=100,
    )

    remarks: str | None = Field(
        default=None,
        max_length=500,
    )


class DeliveryResponse(BaseModel):
    job_card_id: int
    job_code: str
    service_request_id: int
    request_code: str
    invoice_id: int
    invoice_code: str

    delivered_to: str

    recipient_type: str | None
    receiver_name: str | None
    relation_to_customer: str | None

    delivery_remarks: str | None
    delivered_at: datetime

    job_status: str
    service_request_status: str
