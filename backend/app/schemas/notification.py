from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class NotificationCreate(BaseModel):
    recipient_user_id: int = Field(gt=0)

    created_by_user_id: int | None = Field(
        default=None,
        gt=0,
    )

    notification_type: str = Field(
        min_length=1,
        max_length=50,
    )

    title: str = Field(
        min_length=1,
        max_length=150,
    )

    message: str = Field(
        min_length=1,
    )

    entity_type: str | None = Field(
        default=None,
        max_length=50,
    )

    entity_id: int | None = Field(
        default=None,
        gt=0,
    )


class NotificationResponse(BaseModel):
    id: int
    recipient_user_id: int
    created_by_user_id: int | None

    notification_type: str
    title: str
    message: str

    entity_type: str | None
    entity_id: int | None

    status: str
    read_at: datetime | None
    created_at: datetime

    model_config = ConfigDict(
        from_attributes=True,
    )


class NotificationUnreadCountResponse(BaseModel):
    unread_count: int = Field(
        ge=0,
    )


class NotificationMarkAllReadResponse(BaseModel):
    updated_count: int = Field(
        ge=0,
    )
