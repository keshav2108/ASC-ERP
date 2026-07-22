from fastapi import (
    APIRouter,
    Depends,
    Query,
)
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.notification import (
    NotificationMarkAllReadResponse,
    NotificationResponse,
    NotificationUnreadCountResponse,
)
from app.services.notification_service import (
    get_user_notifications,
    get_user_unread_count,
    mark_all_notifications_as_read,
    mark_notification_as_read,
)


router = APIRouter(
    prefix="/api/v1/notifications",
    tags=["Notifications"],
)


@router.get(
    "",
    response_model=list[NotificationResponse],
)
def list_notifications(
    unread_only: bool = Query(
        default=False,
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    limit: int = Query(
        default=50,
        ge=1,
        le=100,
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_user_notifications(
        db,
        current_user.id,
        unread_only=unread_only,
        offset=offset,
        limit=limit,
    )


@router.get(
    "/unread-count",
    response_model=NotificationUnreadCountResponse,
)
def get_unread_notification_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    unread_count = get_user_unread_count(
        db,
        current_user.id,
    )

    return NotificationUnreadCountResponse(
        unread_count=unread_count,
    )


@router.patch(
    "/read-all",
    response_model=NotificationMarkAllReadResponse,
)
def mark_all_notifications_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    updated_count = mark_all_notifications_as_read(
        db,
        current_user.id,
    )

    return NotificationMarkAllReadResponse(
        updated_count=updated_count,
    )


@router.patch(
    "/{notification_id}/read",
    response_model=NotificationResponse,
)
def mark_notification_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return mark_notification_as_read(
        db,
        notification_id,
        current_user.id,
    )
