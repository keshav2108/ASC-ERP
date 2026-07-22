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


class StockTransaction(Base):
    __tablename__ = "stock_transactions"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    spare_part_id = Column(
        Integer,
        ForeignKey("spare_parts.id"),
        nullable=False,
        index=True,
    )

    job_card_id = Column(
        Integer,
        ForeignKey("job_cards.id"),
        nullable=True,
        index=True,
    )

    transaction_type = Column(
        String(30),
        nullable=False,
    )

    quantity = Column(
        Integer,
        nullable=False,
    )

    unit_price = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    line_total = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
    )

    reference = Column(
        String(100),
        nullable=True,
    )

    remarks = Column(
        Text,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )

    spare_part = relationship(
        "SparePart",
    )

    job_card = relationship(
        "JobCard",
        back_populates="stock_transactions",
    )
