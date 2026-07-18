from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base
from app.utils.timezone import get_current_time


class CustomerProduct(Base):
    __tablename__ = "customer_products"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    customer_id = Column(
        Integer,
        ForeignKey("customers.id"),
        nullable=False,
        index=True,
    )

    brand = Column(
        String(100),
        nullable=False,
    )

    product_name = Column(
        String(100),
        nullable=False,
    )

    model_number = Column(
        String(100),
        nullable=True,
    )

    serial_number = Column(
        String(100),
        nullable=True,
        unique=True,
        index=True,
    )

    purchase_date = Column(
        DateTime,
        nullable=True,
    )

    warranty_status = Column(
        String(20),
        nullable=False,
        default="OUT",
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )

    customer = relationship(
        "Customer",
        back_populates="products",
    )

    service_requests = relationship(
        "ServiceRequest",
        back_populates="customer_product",
        cascade="all, delete-orphan",
    )
