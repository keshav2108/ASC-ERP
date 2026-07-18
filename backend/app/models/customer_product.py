from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.database import Base
from app.utils.timezone import get_current_time


class CustomerProduct(Base):

    __tablename__ = "customer_products"


    id = Column(
        Integer,
        primary_key=True,
        index=True
    )


    customer_id = Column(
        Integer,
        ForeignKey("customers.id"),
        nullable=False
    )


    brand = Column(
        String(100),
        nullable=False
    )


    product_name = Column(
        String(100),
        nullable=False
    )


    model_number = Column(
        String(100),
        nullable=True
    )


    serial_number = Column(
        String(100),
        nullable=True
    )


    purchase_date = Column(
        DateTime,
        nullable=True
    )


    warranty_status = Column(
        String(20),
        default="OUT"
    )


    created_at = Column(
        DateTime,
        default=get_current_time
    )

    customer = relationship(
        "Customer",
        back_populates="products"
    )

    service_requests = relationship(
        "ServiceRequest",
        back_populates="customer_product",
        cascade="all, delete-orphan"
    )
