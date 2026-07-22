from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from app.database import Base
from app.utils.timezone import get_current_time


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    recipient_user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    created_by_user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=True,
        index=True,
    )

    notification_type = Column(
        String(50),
        nullable=False,
        index=True,
    )

    title = Column(
        String(150),
        nullable=False,
    )

    message = Column(
        Text,
        nullable=False,
    )

    entity_type = Column(
        String(50),
        nullable=True,
        index=True,
    )

    entity_id = Column(
        Integer,
        nullable=True,
        index=True,
    )

    status = Column(
        String(20),
        nullable=False,
        default="UNREAD",
        index=True,
    )

    read_at = Column(
        DateTime,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
        index=True,
    )

    recipient = relationship(
        "User",
        foreign_keys=[recipient_user_id],
    )

    created_by = relationship(
        "User",
        foreign_keys=[created_by_user_id],
    )

    def __repr__(self) -> str:
        return (
            f"<Notification(id={self.id}, "
            f"recipient_user_id={self.recipient_user_id}, "
            f"type='{self.notification_type}', "
            f"status='{self.status}')>"
        )
