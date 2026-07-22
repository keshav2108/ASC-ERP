from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class TechnicianAssignmentCreate(BaseModel):
    technician_id: int = Field(gt=0)

    diagnosis: str | None = Field(
        default=None,
        max_length=2000,
    )

    repair_notes: str | None = Field(
        default=None,
        max_length=3000,
    )

    labour_charge: Decimal = Field(
        default=Decimal("0.00"),
        ge=0,
    )


class JobCardUpdate(BaseModel):
    technician_id: int | None = Field(
        default=None,
        gt=0,
    )

    diagnosis: str | None = Field(
        default=None,
        max_length=2000,
    )

    repair_notes: str | None = Field(
        default=None,
        max_length=3000,
    )

    labour_charge: Decimal | None = Field(
        default=None,
        ge=0,
    )


class TechnicianSummary(BaseModel):
    id: int
    technician_code: str
    full_name: str
    mobile: str
    specialization: str | None
    availability_status: str

    model_config = {
        "from_attributes": True,
    }


class JobCustomerSummary(BaseModel):
    id: int
    customer_code: str
    full_name: str
    mobile: str

    model_config = {
        "from_attributes": True,
    }


class JobServiceRequestSummary(BaseModel):
    id: int
    request_code: str
    complaint_category: str
    complaint_description: str
    priority: str
    status: str

    customer: JobCustomerSummary

    model_config = {
        "from_attributes": True,
    }


class JobCardResponse(BaseModel):
    id: int
    job_code: str

    service_request_id: int
    technician_id: int

    diagnosis: str | None
    repair_notes: str | None

    labour_charge: Decimal
    status: str

    assigned_at: datetime
    started_at: datetime | None
    completed_at: datetime | None

    delivered_at: datetime | None
    delivered_to: str | None

    recipient_type: str | None
    receiver_name: str | None
    relation_to_customer: str | None

    delivery_remarks: str | None

    created_at: datetime

    technician: TechnicianSummary
    service_request: JobServiceRequestSummary

    # Computed spare-part fields (Phase 4)
    total_parts_cost: Decimal = Field(default=Decimal("0.00"))
    parts_used_count: int = Field(default=0)

    model_config = {
        "from_attributes": True,
    }
