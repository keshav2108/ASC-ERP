from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.permissions import require_roles
from app.database import get_db
from app.schemas.delivery import (
    DeliveryCreate,
    DeliveryResponse,
)
from app.services.delivery_service import (
    deliver_product,
    get_delivery_details,
)


delivery_view_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
    "ACCOUNTANT",
)

delivery_manage_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
)


router = APIRouter(
    prefix="/api/v1/deliveries",
    tags=["Deliveries"],
)


@router.post(
    "/job-card/{job_card_id}",
    response_model=DeliveryResponse,
    dependencies=[
        Depends(delivery_manage_access),
    ],
)
def deliver_job_card_product(
    job_card_id: int,
    delivery_data: DeliveryCreate,
    db: Session = Depends(get_db),
):
    return deliver_product(
        db,
        job_card_id,
        delivery_data,
    )


@router.get(
    "/job-card/{job_card_id}",
    response_model=DeliveryResponse,
    dependencies=[
        Depends(delivery_view_access),
    ],
)
def view_delivery_details(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return get_delivery_details(
        db,
        job_card_id,
    )
