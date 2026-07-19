from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Integer,
    Numeric,
    String,
)

from app.database import Base
from app.utils.timezone import get_current_time


class SparePart(Base):
    __tablename__ = "spare_parts"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    part_code = Column(
        String(20),
        unique=True,
        nullable=False,
        index=True,
    )

    part_name = Column(
        String(150),
        nullable=False,
    )

    brand = Column(
        String(100),
        nullable=True,
    )

    product_category = Column(
        String(100),
        nullable=True,
    )

    unit = Column(
        String(30),
        nullable=False,
        default="PIECE",
    )

    purchase_price = Column(
        Numeric(10, 2),
        nullable=False,
        default=0,
    )

    selling_price = Column(
        Numeric(10, 2),
        nullable=False,
        default=0,
    )

    current_stock = Column(
        Integer,
        nullable=False,
        default=0,
    )

    minimum_stock = Column(
        Integer,
        nullable=False,
        default=0,
    )

    is_active = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )
