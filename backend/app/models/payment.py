from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import relationship

from app.database import Base
from app.utils.timezone import get_current_time


class Payment(Base):
    __tablename__ = "payments"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    payment_code = Column(
        String(25),
        unique=True,
        nullable=False,
        index=True,
    )

    invoice_id = Column(
        Integer,
        ForeignKey("invoices.id"),
        nullable=False,
        index=True,
    )

    amount = Column(
        Numeric(12, 2),
        nullable=False,
    )

    payment_method = Column(
        String(30),
        nullable=False,
    )

    transaction_reference = Column(
        String(100),
        nullable=True,
    )

    remarks = Column(
        String(500),
        nullable=True,
    )

    status = Column(
        String(30),
        nullable=False,
        default="SUCCESS",
    )

    paid_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )

    invoice = relationship(
        "Invoice",
        back_populates="payments",
    )
