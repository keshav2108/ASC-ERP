from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from app.database import Base
from app.utils.timezone import get_current_time


class JobCard(Base):
    __tablename__ = "job_cards"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    job_code = Column(
        String(20),
        unique=True,
        nullable=False,
        index=True,
    )

    service_request_id = Column(
        Integer,
        ForeignKey("service_requests.id"),
        unique=True,
        nullable=False,
        index=True,
    )

    technician_id = Column(
        Integer,
        ForeignKey("technicians.id"),
        nullable=False,
        index=True,
    )

    diagnosis = Column(
        Text,
        nullable=True,
    )

    repair_notes = Column(
        Text,
        nullable=True,
    )

    labour_charge = Column(
        Numeric(10, 2),
        nullable=False,
        default=0,
    )

    status = Column(
        String(30),
        nullable=False,
        default="ASSIGNED",
    )

    assigned_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )

    started_at = Column(
        DateTime,
        nullable=True,
    )

    completed_at = Column(
        DateTime,
        nullable=True,
    )

    delivered_at = Column(
        DateTime,
        nullable=True,
    )

    delivered_to = Column(
        String(100),
        nullable=True,
    )

    delivery_remarks = Column(
        String(500),
        nullable=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )

    service_request = relationship(
        "ServiceRequest",
        back_populates="job_card",
    )

    technician = relationship(
        "Technician",
        back_populates="job_cards",
    )

    invoice = relationship(
        "Invoice",
        back_populates="job_card",
        uselist=False,
        cascade="all, delete-orphan",
    )
