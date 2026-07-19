from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy.orm import relationship

from app.database import Base
from app.utils.timezone import get_current_time


class Technician(Base):
    __tablename__ = "technicians"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    technician_code = Column(
        String(20),
        unique=True,
        nullable=False,
        index=True,
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        unique=True,
        nullable=True,
    )

    full_name = Column(
        String(100),
        nullable=False,
    )

    mobile = Column(
        String(15),
        unique=True,
        nullable=False,
    )

    specialization = Column(
        String(150),
        nullable=True,
    )

    experience_years = Column(
        Integer,
        nullable=False,
        default=0,
    )

    availability_status = Column(
        String(30),
        nullable=False,
        default="AVAILABLE",
    )

    status = Column(
        String(20),
        nullable=False,
        default="ACTIVE",
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )

    user = relationship("User")

    job_cards = relationship(
        "JobCard",
        back_populates="technician",
    )
