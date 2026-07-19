from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.delivery import (
    DeliveryCreate,
    DeliveryResponse,
)
from app.services.delivery_service import (
    deliver_product,
    get_delivery_details,
)


router = APIRouter(
    prefix="/api/v1/deliveries",
    tags=["Deliveries"],
)


@router.post(
    "/job-card/{job_card_id}",
    response_model=DeliveryResponse,
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
)
def view_delivery_details(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return get_delivery_details(
        db,
        job_card_id,
    )
