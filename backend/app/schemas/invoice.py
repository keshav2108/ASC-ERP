from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class InvoiceCreate(BaseModel):
    job_card_id: int = Field(gt=0)

    discount_amount: Decimal = Field(
        default=Decimal("0.00"),
        ge=0,
    )

    gst_percentage: Decimal = Field(
        default=Decimal("0.00"),
        ge=0,
        le=100,
    )


class InvoiceItemResponse(BaseModel):
    id: int
    invoice_id: int
    spare_part_id: int | None
    item_type: str
    description: str
    quantity: int
    unit_price: Decimal
    total_price: Decimal

    model_config = {
        "from_attributes": True
    }


class InvoiceCustomerSummary(BaseModel):
    id: int
    customer_code: str
    full_name: str
    mobile: str
    email: str | None
    address: str | None
    city: str | None
    pincode: str | None

    model_config = {
        "from_attributes": True
    }


class InvoiceJobCardSummary(BaseModel):
    id: int
    job_code: str
    service_request_id: int
    technician_id: int
    diagnosis: str | None
    repair_notes: str | None
    labour_charge: Decimal
    status: str

    model_config = {
        "from_attributes": True
    }


class InvoiceResponse(BaseModel):
    id: int
    invoice_code: str
    job_card_id: int
    customer_id: int

    labour_amount: Decimal
    parts_amount: Decimal
    subtotal: Decimal
    discount_amount: Decimal
    taxable_amount: Decimal
    gst_percentage: Decimal
    gst_amount: Decimal
    total_amount: Decimal

    payment_status: str
    status: str
    created_at: datetime

    customer: InvoiceCustomerSummary
    job_card: InvoiceJobCardSummary
    items: list[InvoiceItemResponse]

    model_config = {
        "from_attributes": True
    }
