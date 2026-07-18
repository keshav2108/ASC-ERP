from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    ForeignKey,
    Text
)

from sqlalchemy.orm import relationship

from app.database import Base
from app.utils.timezone import get_current_time


class ServiceRequest(Base):

    __tablename__ = "service_requests"


    id = Column(
        Integer,
        primary_key=True,
        index=True
    )


    request_code = Column(
        String(20),
        unique=True,
        nullable=False
    )


    customer_id = Column(
        Integer,
        ForeignKey("customers.id"),
        nullable=False
    )


    customer_product_id = Column(
        Integer,
        ForeignKey("customer_products.id"),
        nullable=False
    )


    complaint_category = Column(
        String(100),
        nullable=False
    )


    complaint_description = Column(
        Text,
        nullable=False
    )


    received_accessories = Column(
        String(255),
        nullable=True
    )


    product_condition = Column(
        String(100),
        nullable=True
    )


    priority = Column(
        String(20),
        default="NORMAL"
    )


    status = Column(
        String(30),
        default="OPEN"
    )


    estimated_delivery = Column(
        DateTime,
        nullable=True
    )


    created_at = Column(
        DateTime,
        default=get_current_time
    )


    customer = relationship(
        "Customer",
        back_populates="service_requests"
    )


    customer_product = relationship(
        "CustomerProduct",
        back_populates="service_requests"
    )
