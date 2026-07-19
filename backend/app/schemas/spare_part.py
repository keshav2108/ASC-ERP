from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class SparePartCreate(BaseModel):
    part_name: str = Field(
        min_length=2,
        max_length=150,
    )

    brand: str | None = Field(
        default=None,
        max_length=100,
    )

    product_category: str | None = Field(
        default=None,
        max_length=100,
    )

    unit: str = Field(
        default="PIECE",
        min_length=1,
        max_length=30,
    )

    purchase_price: Decimal = Field(
        default=Decimal("0.00"),
        ge=0,
    )

    selling_price: Decimal = Field(
        default=Decimal("0.00"),
        ge=0,
    )

    current_stock: int = Field(
        default=0,
        ge=0,
    )

    minimum_stock: int = Field(
        default=0,
        ge=0,
    )


class SparePartUpdate(BaseModel):
    part_name: str | None = Field(
        default=None,
        min_length=2,
        max_length=150,
    )

    brand: str | None = Field(
        default=None,
        max_length=100,
    )

    product_category: str | None = Field(
        default=None,
        max_length=100,
    )

    unit: str | None = Field(
        default=None,
        min_length=1,
        max_length=30,
    )

    purchase_price: Decimal | None = Field(
        default=None,
        ge=0,
    )

    selling_price: Decimal | None = Field(
        default=None,
        ge=0,
    )

    minimum_stock: int | None = Field(
        default=None,
        ge=0,
    )

    is_active: bool | None = None


class SparePartResponse(BaseModel):
    id: int
    part_code: str
    part_name: str
    brand: str | None
    product_category: str | None
    unit: str
    purchase_price: Decimal
    selling_price: Decimal
    current_stock: int
    minimum_stock: int
    is_active: bool
    created_at: datetime

    model_config = {
        "from_attributes": True
    }
