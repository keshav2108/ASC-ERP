from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.job_card import JobCard
from app.models.service_request import ServiceRequest
from app.models.technician import Technician
from app.schemas.job_card import (
    JobCardUpdate,
    TechnicianAssignmentCreate,
)
from app.utils.id_generator import generate_code


def get_job_card_by_id(
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


def assign_technician_and_create_job_card(
    db: Session,
    service_request_id: int,
    assignment_data: TechnicianAssignmentCreate,
):
    service_request = (
        db.query(ServiceRequest)
        .filter(
            ServiceRequest.id == service_request_id
        )
        .first()
    )

    if not service_request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service request not found",
        )

    if service_request.status in {
        "CANCELLED",
        "DELIVERED",
        "COMPLETED",
    }:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Technician cannot be assigned "
                "to this service request"
            ),
        )

    existing_job_card = (
        db.query(JobCard)
        .filter(
            JobCard.service_request_id
            == service_request_id
        )
        .first()
    )

    if existing_job_card:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "A technician is already assigned "
                "to this service request"
            ),
        )

    technician = (
        db.query(Technician)
        .filter(
            Technician.id
            == assignment_data.technician_id,
            Technician.status == "ACTIVE",
        )
        .first()
    )

    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active technician not found",
        )

    job_status = validate_master_option(
        db,
        "JOB_STATUS",
        "ASSIGNED",
    )

    service_status = validate_master_option(
        db,
        "SERVICE_STATUS",
        "ASSIGNED",
    )

    job_count = db.query(JobCard).count()

    job_card = JobCard(
        job_code=generate_code(
            "JOB",
            job_count + 1,
        ),
        service_request_id=service_request_id,
        technician_id=assignment_data.technician_id,
        diagnosis=assignment_data.diagnosis,
        repair_notes=assignment_data.repair_notes,
        labour_charge=assignment_data.labour_charge,
        status=job_status,
    )

    service_request.status = service_status

    db.add(job_card)

    try:
        db.commit()
        db.refresh(job_card)

    except Exception:
        db.rollback()
        raise

    return job_card


def get_job_cards(
    db: Session,
):
    return (
        db.query(JobCard)
        .order_by(JobCard.id.desc())
        .all()
    )


def get_technician_job_cards(
    db: Session,
    technician_id: int,
):
    technician = (
        db.query(Technician)
        .filter(Technician.id == technician_id)
        .first()
    )

    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Technician not found",
        )

    return (
        db.query(JobCard)
        .filter(
            JobCard.technician_id == technician_id
        )
        .order_by(JobCard.id.desc())
        .all()
    )


def update_job_card(
    db: Session,
    job_card_id: int,
    job_data: JobCardUpdate,
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    update_data = job_data.model_dump(
        exclude_unset=True
    )

    if "technician_id" in update_data:
        new_technician = (
            db.query(Technician)
            .filter(
                Technician.id
                == update_data["technician_id"],
                Technician.status == "ACTIVE",
            )
            .first()
        )

        if not new_technician:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Active technician not found",
            )


    for field, value in update_data.items():
        setattr(
            job_card,
            field,
            value,
        )


    try:
        db.commit()
        db.refresh(job_card)

    except Exception:
        db.rollback()
        raise

    return job_card
