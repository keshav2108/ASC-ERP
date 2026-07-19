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


class Invoice(Base):
    __tablename__ = "invoices"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    invoice_code = Column(
        String(25),
        unique=True,
        nullable=False,
        index=True,
    )

    job_card_id = Column(
        Integer,
        ForeignKey("job_cards.id"),
        unique=True,
        nullable=False,
        index=True,
    )

    customer_id = Column(
        Integer,
        ForeignKey("customers.id"),
        nullable=False,
        index=True,
    )

    labour_amount = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    parts_amount = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    subtotal = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    discount_amount = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    taxable_amount = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    gst_percentage = Column(
        Numeric(5, 2),
        nullable=False,
        default=0,
    )

    gst_amount = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    total_amount = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    payment_status = Column(
        String(30),
        nullable=False,
        default="UNPAID",
    )

    status = Column(
        String(30),
        nullable=False,
        default="GENERATED",
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )

    job_card = relationship(
        "JobCard",
        back_populates="invoice",
    )

    customer = relationship(
        "Customer",
    )

    items = relationship(
        "InvoiceItem",
        back_populates="invoice",
        cascade="all, delete-orphan",
    )

    payments = relationship(
        "Payment",
        back_populates="invoice",
        cascade="all, delete-orphan",
    )
