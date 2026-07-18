from sqlalchemy import Column, DateTime, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base
from app.utils.timezone import get_current_time


class Customer(Base):

    __tablename__ = "customers"


    id = Column(
        Integer,
        primary_key=True,
        index=True
    )


    customer_code = Column(
        String(20),
        unique=True,
        nullable=False
    )


    full_name = Column(
        String(100),
        nullable=False
    )


    mobile = Column(
        String(15),
        unique=True,
        nullable=False
    )


    alternate_mobile = Column(
        String(15),
        nullable=True
    )


    email = Column(
        String(100),
        nullable=True
    )


    address = Column(
        String(255),
        nullable=True
    )


    city = Column(
        String(100),
        nullable=True
    )


    pincode = Column(
        String(10),
        nullable=True
    )


    status = Column(
        String(20),
        default="ACTIVE"
    )


    created_at = Column(
        DateTime,
        default=get_current_time
    )


    products = relationship(
        "CustomerProduct",
        back_populates="customer",
        cascade="all, delete-orphan"
    )


    service_requests = relationship(
        "ServiceRequest",
        back_populates="customer",
        cascade="all, delete-orphan"
    )
