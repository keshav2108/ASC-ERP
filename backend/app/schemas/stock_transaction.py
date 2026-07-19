from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field

from app.schemas.spare_part import SparePartResponse


class StockInCreate(BaseModel):
    spare_part_id: int = Field(gt=0)

    quantity: int = Field(gt=0)

    reference: str | None = Field(
        default=None,
        max_length=100,
    )

    remarks: str | None = Field(
        default=None,
        max_length=1000,
    )


class StockIssueCreate(BaseModel):
    spare_part_id: int = Field(gt=0)

    job_card_id: int = Field(gt=0)

    quantity: int = Field(gt=0)

    remarks: str | None = Field(
        default=None,
        max_length=1000,
    )


class StockReturnCreate(BaseModel):
    spare_part_id: int = Field(gt=0)

    job_card_id: int = Field(gt=0)

    quantity: int = Field(gt=0)

    remarks: str | None = Field(
        default=None,
        max_length=1000,
    )


class StockAdjustmentCreate(BaseModel):
    spare_part_id: int = Field(gt=0)

    new_quantity: int = Field(ge=0)

    remarks: str = Field(
        min_length=3,
        max_length=1000,
    )


class StockTransactionResponse(BaseModel):
    id: int
    spare_part_id: int
    job_card_id: int | None
    transaction_type: str
    quantity: int
    unit_price: Decimal
    line_total: Decimal
    reference: str | None
    remarks: str | None
    created_at: datetime

    spare_part: SparePartResponse

    model_config = {
        "from_attributes": True
    }
