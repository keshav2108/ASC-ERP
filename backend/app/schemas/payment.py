from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class PaymentCreate(BaseModel):
    invoice_id: int = Field(gt=0)

    amount: Decimal = Field(
        gt=0,
    )

    payment_method: str = Field(
        min_length=2,
        max_length=30,
    )

    transaction_reference: str | None = Field(
        default=None,
        max_length=100,
    )

    remarks: str | None = Field(
        default=None,
        max_length=500,
    )


class PaymentResponse(BaseModel):
    id: int
    payment_code: str
    invoice_id: int
    amount: Decimal
    payment_method: str
    transaction_reference: str | None
    remarks: str | None
    status: str
    paid_at: datetime
    created_at: datetime

    model_config = {
        "from_attributes": True
    }


class InvoicePaymentSummary(BaseModel):
    invoice_id: int
    invoice_code: str
    total_amount: Decimal
    paid_amount: Decimal
    balance_amount: Decimal
    payment_status: str
    payments: list[PaymentResponse]
