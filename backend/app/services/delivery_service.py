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

    recipient_type = delivery_data.recipient_type

    if recipient_type == "CUSTOMER":
        customer = job_card.service_request.customer

        if not customer:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Customer information is not available "
                    "for this service request"
                ),
            )

        receiver_name = customer.full_name.strip()

        if not receiver_name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Customer name is not available",
            )

        relation_to_customer = "Customer / Self"

    else:
        receiver_name = (
            delivery_data.receiver_name or ""
        ).strip()

        relation_to_customer = (
            delivery_data.relation_to_customer or ""
        ).strip()

        if len(receiver_name) < 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Receiver name is required "
                    "for Other recipient"
                ),
            )

        if len(relation_to_customer) < 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Relation to customer is required "
                    "for Other recipient"
                ),
            )

    remarks = (
        delivery_data.remarks.strip()
        if delivery_data.remarks
        and delivery_data.remarks.strip()
        else None
    )

    job_card.status = job_status
    job_card.delivered_at = delivered_at
    job_card.delivered_to = receiver_name
    job_card.recipient_type = recipient_type
    job_card.receiver_name = receiver_name
    job_card.relation_to_customer = relation_to_customer
    job_card.delivery_remarks = remarks

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
        "recipient_type": job_card.recipient_type,
        "receiver_name": job_card.receiver_name,
        "relation_to_customer": (
            job_card.relation_to_customer
        ),
        "delivery_remarks": (
            job_card.delivery_remarks
        ),
        "delivered_at": job_card.delivered_at,
        "job_status": job_card.status,
        "service_request_status": (
            job_card.service_request.status
        ),
    }


def reopen_delivered_product(
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
            detail=(
                "Only a delivered product can be moved "
                "back to Ready for Delivery"
            ),
        )

    validate_workflow_transition(
        db,
        job_card.status,
        "READY_FOR_DELIVERY",
    )

    job_status = validate_master_option(
        db,
        "JOB_STATUS",
        "READY_FOR_DELIVERY",
    )

    service_status = validate_master_option(
        db,
        "SERVICE_STATUS",
        "READY_FOR_DELIVERY",
    )

    job_card.status = job_status
    job_card.service_request.status = service_status

    job_card.delivered_at = None
    job_card.delivered_to = None
    job_card.recipient_type = None
    job_card.receiver_name = None
    job_card.relation_to_customer = None
    job_card.delivery_remarks = None

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

    return job_card


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
        "recipient_type": job_card.recipient_type,
        "receiver_name": job_card.receiver_name,
        "relation_to_customer": (
            job_card.relation_to_customer
        ),
        "delivery_remarks": (
            job_card.delivery_remarks
        ),
        "delivered_at": job_card.delivered_at,
        "job_status": job_card.status,
        "service_request_status": (
            job_card.service_request.status
        ),
    }
