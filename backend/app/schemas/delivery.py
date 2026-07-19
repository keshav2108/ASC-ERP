from datetime import datetime

from pydantic import BaseModel, Field


class DeliveryCreate(BaseModel):
    delivered_to: str = Field(
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
    delivery_remarks: str | None
    delivered_at: datetime
    job_status: str
    service_request_status: str
