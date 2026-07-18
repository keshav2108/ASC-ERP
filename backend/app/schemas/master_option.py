from datetime import datetime

from pydantic import BaseModel, Field


class MasterOptionCreate(BaseModel):
    option_type: str = Field(
        min_length=2,
        max_length=50,
    )

    code: str = Field(
        min_length=1,
        max_length=50,
    )

    label: str = Field(
        min_length=1,
        max_length=100,
    )

    display_order: int = Field(
        default=0,
        ge=0,
    )


class MasterOptionUpdate(BaseModel):
    label: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
    )

    display_order: int | None = Field(
        default=None,
        ge=0,
    )

    is_active: bool | None = None


class MasterOptionResponse(BaseModel):
    id: int
    option_type: str
    code: str
    label: str
    display_order: int
    is_active: bool
    created_at: datetime

    model_config = {
        "from_attributes": True
    }
