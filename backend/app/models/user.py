from sqlalchemy import Column, DateTime, Integer, String
from sqlalchemy.sql import func

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    employee_id = Column(
        String(20),
        unique=True,
        nullable=False,
        index=True,
    )

    full_name = Column(
        String(100),
        nullable=False,
    )

    username = Column(
        String(50),
        unique=True,
        nullable=True,
        index=True,
    )

    email = Column(
        String(100),
        unique=True,
        nullable=True,
        index=True,
    )

    mobile = Column(
        String(15),
        unique=True,
        nullable=False,
        index=True,
    )

    password_hash = Column(
        String(255),
        nullable=False,
    )

    role = Column(
        String(30),
        nullable=False,
    )

    status = Column(
        String(20),
        nullable=True,
        default="active",
    )

    created_at = Column(
        DateTime,
        nullable=True,
        server_default=func.now(),
    )

    def __repr__(self) -> str:
        return (
            f"<User(id={self.id}, "
            f"username='{self.username}', "
            f"mobile='{self.mobile}')>"
        )
