from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.notification import Notification
from app.schemas.notification import NotificationCreate
from app.utils.timezone import get_current_time


def create_notification(
    db: Session,
    notification_data: NotificationCreate,
) -> Notification:
    """
    Add a notification to the current database transaction.

    This function intentionally does not commit. The calling service
    controls the final transaction so the related business operation
    and notification succeed or fail together.
    """

    notification = Notification(
        **notification_data.model_dump(),
        status="UNREAD",
    )

    db.add(notification)
    db.flush()

    return notification


def get_user_notifications(
    db: Session,
    recipient_user_id: int,
    *,
    unread_only: bool = False,
    offset: int = 0,
    limit: int = 50,
) -> list[Notification]:
    query = db.query(Notification).filter(
        Notification.recipient_user_id
        == recipient_user_id,
    )

    if unread_only:
        query = query.filter(
            Notification.status == "UNREAD",
        )

    return (
        query.order_by(
            Notification.created_at.desc(),
            Notification.id.desc(),
        )
        .offset(offset)
        .limit(limit)
        .all()
    )


def get_user_unread_count(
    db: Session,
    recipient_user_id: int,
) -> int:
    unread_count = (
        db.query(func.count(Notification.id))
        .filter(
            Notification.recipient_user_id
            == recipient_user_id,
            Notification.status == "UNREAD",
        )
        .scalar()
    )

    return int(unread_count or 0)


def mark_notification_as_read(
    db: Session,
    notification_id: int,
    recipient_user_id: int,
) -> Notification:
    notification = (
        db.query(Notification)
        .filter(
            Notification.id == notification_id,
            Notification.recipient_user_id
            == recipient_user_id,
        )
        .first()
    )

    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found",
        )

    if notification.status != "READ":
        notification.status = "READ"
        notification.read_at = get_current_time()

        try:
            db.commit()
            db.refresh(notification)

        except Exception:
            db.rollback()
            raise

    return notification


def mark_all_notifications_as_read(
    db: Session,
    recipient_user_id: int,
) -> int:
    unread_notifications = (
        db.query(Notification)
        .filter(
            Notification.recipient_user_id
            == recipient_user_id,
            Notification.status == "UNREAD",
        )
        .all()
    )

    if not unread_notifications:
        return 0

    read_at = get_current_time()

    for notification in unread_notifications:
        notification.status = "READ"
        notification.read_at = read_at

    try:
        db.commit()

    except Exception:
        db.rollback()
        raise

    return len(unread_notifications)
