from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.invoice import Invoice
from app.models.job_card import JobCard
from app.schemas.delivery import DeliveryCreate
from app.services.master_validation_service import (
    validate_master_option,
)
from app.services.workflow_transition_service import (
    validate_workflow_transition,
)
from app.utils.timezone import get_current_time


def deliver_product(
    db: Session,
    job_card_id: int,
    delivery_data: DeliveryCreate,
):
    job_card = (
        db.query(JobCard)
        .filter(JobCard.id == job_card_id)
        .first()
    )

    if not job_card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Job card not found",
        )

    if job_card.status == "DELIVERED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Product is already delivered",
        )

    if job_card.status != "READY_FOR_DELIVERY":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Job card must be READY_FOR_DELIVERY "
                "before product delivery"
            ),
        )

    invoice = (
        db.query(Invoice)
        .filter(
            Invoice.job_card_id == job_card.id
        )
        .first()
    )

    if not invoice:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invoice not found for this job card",
        )

    if invoice.status == "CANCELLED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cancelled invoice cannot be delivered",
        )

    if invoice.payment_status != "PAID":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Invoice must be fully paid "
                "before delivery"
            ),
        )

    validate_workflow_transition(
        db,
        job_card.status,
        "DELIVERED",
    )

    job_status = validate_master_option(
        db,
        "JOB_STATUS",
        "DELIVERED",
    )

    service_status = validate_master_option(
        db,
        "SERVICE_STATUS",
        "DELIVERED",
    )

    delivered_at = get_current_time()

    job_card.status = job_status
    job_card.delivered_at = delivered_at
    job_card.delivered_to = (
        delivery_data.delivered_to.strip()
    )
    job_card.delivery_remarks = delivery_data.remarks

    job_card.service_request.status = service_status

    if job_card.technician:
        job_card.technician.availability_status = (
            "AVAILABLE"
        )

    try:
        db.commit()
        db.refresh(job_card)

    except Exception:
        db.rollback()
        raise

    return {
        "job_card_id": job_card.id,
        "job_code": job_card.job_code,
        "service_request_id": (
            job_card.service_request.id
        ),
        "request_code": (
            job_card.service_request.request_code
        ),
        "invoice_id": invoice.id,
        "invoice_code": invoice.invoice_code,
        "delivered_to": job_card.delivered_to,
        "delivery_remarks": (
            job_card.delivery_remarks
        ),
        "delivered_at": job_card.delivered_at,
        "job_status": job_card.status,
        "service_request_status": (
            job_card.service_request.status
        ),
    }


def get_delivery_details(
    db: Session,
    job_card_id: int,
):
    job_card = (
        db.query(JobCard)
        .filter(JobCard.id == job_card_id)
        .first()
    )

    if not job_card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Job card not found",
        )

    if job_card.status != "DELIVERED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Product has not been delivered",
        )

    invoice = job_card.invoice

    if not invoice:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invoice not found",
        )

    return {
        "job_card_id": job_card.id,
        "job_code": job_card.job_code,
        "service_request_id": (
            job_card.service_request.id
        ),
        "request_code": (
            job_card.service_request.request_code
        ),
        "invoice_id": invoice.id,
        "invoice_code": invoice.invoice_code,
        "delivered_to": job_card.delivered_to,
        "delivery_remarks": (
            job_card.delivery_remarks
        ),
        "delivered_at": job_card.delivered_at,
        "job_status": job_card.status,
        "service_request_status": (
            job_card.service_request.status
        ),
    }
