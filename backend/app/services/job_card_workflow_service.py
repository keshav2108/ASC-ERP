from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.job_card import JobCard
from app.services.master_validation_service import (
    validate_master_option,
)
from app.services.workflow_transition_service import (
    normalize_status,
    validate_workflow_transition,
)
from app.utils.timezone import get_current_time


def get_job_card_for_workflow(
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

    return job_card


def change_job_card_status(
    db: Session,
    job_card_id: int,
    new_status: str,
):
    job_card = get_job_card_for_workflow(
        db,
        job_card_id,
    )

    current_status = normalize_status(
        job_card.status
    )

    normalized_new_status = normalize_status(
        new_status
    )

    if normalized_new_status == "DELIVERED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Use the delivery endpoint to mark "
                "a product as delivered"
            ),
        )

    validate_workflow_transition(
        db,
        current_status,
        normalized_new_status,
    )

    job_status = validate_master_option(
        db,
        "JOB_STATUS",
        normalized_new_status,
    )

    service_status = validate_master_option(
        db,
        "SERVICE_STATUS",
        normalized_new_status,
    )

    job_card.status = job_status
    job_card.service_request.status = service_status

    if current_status in {
        "COMPLETED",
        "READY_FOR_DELIVERY",
    } and normalized_new_status in {
        "DIAGNOSIS",
        "REPAIR_IN_PROGRESS",
        "TESTING",
    }:
        job_card.completed_at = None

    if normalized_new_status in {
        "ACCEPTED",
        "DIAGNOSIS",
        "REPAIR_IN_PROGRESS",
    }:
        if job_card.started_at is None:
            job_card.started_at = get_current_time()


    if normalized_new_status == "COMPLETED":
        if job_card.completed_at is None:
            job_card.completed_at = get_current_time()

        if job_card.technician:
            job_card.technician.availability_status = (
                "AVAILABLE"
            )

    if normalized_new_status in {
        "READY_FOR_DELIVERY",
        "CANCELLED",
    }:
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
