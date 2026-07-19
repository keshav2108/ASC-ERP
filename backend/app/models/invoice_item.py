from sqlalchemy import (
    Column,
    ForeignKey,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import relationship

from app.database import Base


class InvoiceItem(Base):
    __tablename__ = "invoice_items"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    invoice_id = Column(
        Integer,
        ForeignKey("invoices.id"),
        nullable=False,
        index=True,
    )

    spare_part_id = Column(
        Integer,
        ForeignKey("spare_parts.id"),
        nullable=True,
        index=True,
    )

    item_type = Column(
        String(30),
        nullable=False,
    )

    description = Column(
        String(255),
        nullable=False,
    )

    quantity = Column(
        Integer,
        nullable=False,
        default=1,
    )

    unit_price = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    total_price = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    invoice = relationship(
        "Invoice",
        back_populates="items",
    )

    spare_part = relationship(
        "SparePart",
    )
