from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class CustomerSummary(BaseModel):
    id: int
    customer_code: str
    full_name: str
    mobile: str

    model_config = {
        "from_attributes": True,
    }


class CustomerProductSummary(BaseModel):
    id: int
    customer_id: int
    brand: str
    product_name: str
    model_number: str | None
    serial_number: str | None
    warranty_status: str

    model_config = {
        "from_attributes": True,
    }


class ServiceRequestCreate(BaseModel):
    customer_id: int = Field(gt=0)

    customer_product_id: int = Field(gt=0)

    complaint_category: str = Field(
        min_length=1,
        max_length=50,
    )

    complaint_description: str = Field(
        min_length=3,
        max_length=1000,
    )

    received_accessories: str | None = Field(
        default=None,
        max_length=255,
    )

    product_condition: str = Field(
        default="GOOD",
        min_length=1,
        max_length=50,
    )

    priority: str = Field(
        default="NORMAL",
        min_length=1,
        max_length=50,
    )

    estimated_delivery: datetime | None = None


class ComplaintCustomerCreate(BaseModel):
    full_name: str = Field(
        min_length=2,
        max_length=100,
    )

    mobile: str = Field(
        min_length=10,
        max_length=10,
        pattern=r"^\d{10}$",
    )

    alternate_mobile: str | None = Field(
        default=None,
        min_length=10,
        max_length=10,
        pattern=r"^\d{10}$",
    )

    email: EmailStr | None = None

    address: str | None = Field(
        default=None,
        max_length=255,
    )

    city: str | None = Field(
        default=None,
        max_length=100,
    )

    pincode: str | None = Field(
        default=None,
        max_length=10,
    )


class ComplaintProductCreate(BaseModel):
    customer_product_id: int | None = Field(
        default=None,
        gt=0,
    )

    brand: str = Field(
        min_length=1,
        max_length=100,
    )

    product_name: str = Field(
        min_length=1,
        max_length=100,
    )

    model_number: str | None = Field(
        default=None,
        max_length=100,
    )

    serial_number: str | None = Field(
        default=None,
        max_length=100,
    )

    purchase_date: datetime | None = None

    warranty_status: str = Field(
        default="OUT",
        min_length=1,
        max_length=20,
    )


class ComplaintDetailsCreate(BaseModel):
    complaint_category: str = Field(
        min_length=1,
        max_length=50,
    )

    complaint_description: str = Field(
        min_length=3,
        max_length=1000,
    )

    received_accessories: str | None = Field(
        default=None,
        max_length=255,
    )

    product_condition: str = Field(
        default="GOOD",
        min_length=1,
        max_length=50,
    )

    priority: str = Field(
        default="NORMAL",
        min_length=1,
        max_length=50,
    )

    estimated_delivery: datetime | None = None


class RegisterComplaintCreate(BaseModel):
    customer: ComplaintCustomerCreate
    product: ComplaintProductCreate
    complaint: ComplaintDetailsCreate


class ServiceRequestUpdate(BaseModel):
    complaint_category: str | None = Field(
        default=None,
        min_length=1,
        max_length=50,
    )

    complaint_description: str | None = Field(
        default=None,
        min_length=3,
        max_length=1000,
    )

    received_accessories: str | None = Field(
        default=None,
        max_length=255,
    )

    product_condition: str | None = Field(
        default=None,
        min_length=1,
        max_length=50,
    )

    priority: str | None = Field(
        default=None,
        min_length=1,
        max_length=50,
    )

    status: str | None = Field(
        default=None,
        min_length=1,
        max_length=50,
    )

    estimated_delivery: datetime | None = None


class ServiceRequestResponse(BaseModel):
    id: int
    request_code: str

    customer_id: int
    customer_product_id: int

    complaint_category: str
    complaint_description: str

    received_accessories: str | None
    product_condition: str

    priority: str
    status: str

    estimated_delivery: datetime | None
    created_at: datetime

    customer: CustomerSummary
    customer_product: CustomerProductSummary

    model_config = {
        "from_attributes": True,
    }
