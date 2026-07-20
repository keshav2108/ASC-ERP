from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.job_card import (
    JobCardResponse,
    JobCardUpdate,
)
from app.services.job_card_service import (
    get_job_card_by_id,
    get_job_cards,
    get_technician_job_cards,
    update_job_card,
)
from app.services.job_card_workflow_service import (
    change_job_card_status,
)


router = APIRouter(
    prefix="/api/v1/job-cards",
    tags=["Job Cards"],
)


@router.get(
    "/",
    response_model=list[JobCardResponse],
)
def list_job_cards(
    db: Session = Depends(get_db),
):
    return get_job_cards(db)


@router.get(
    "/technician/{technician_id}",
    response_model=list[JobCardResponse],
)
def list_technician_job_cards(
    technician_id: int,
    db: Session = Depends(get_db),
):
    return get_technician_job_cards(
        db,
        technician_id,
    )


@router.get(
    "/{job_card_id}",
    response_model=JobCardResponse,
)
def get_job_card(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return get_job_card_by_id(
        db,
        job_card_id,
    )


@router.patch(
    "/{job_card_id}",
    response_model=JobCardResponse,
)
def edit_job_card(
    job_card_id: int,
    job_data: JobCardUpdate,
    db: Session = Depends(get_db),
):
    return update_job_card(
        db,
        job_card_id,
        job_data,
    )


@router.post(
    "/{job_card_id}/accept",
    response_model=JobCardResponse,
)
def accept_job(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "ACCEPTED",
    )


@router.post(
    "/{job_card_id}/start-diagnosis",
    response_model=JobCardResponse,
)
def start_diagnosis(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "DIAGNOSIS",
    )


@router.post(
    "/{job_card_id}/waiting-for-parts",
    response_model=JobCardResponse,
)
def waiting_for_parts(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "WAITING_PARTS",
    )


@router.post(
    "/{job_card_id}/start-repair",
    response_model=JobCardResponse,
)
def start_repair(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "REPAIR_IN_PROGRESS",
    )


@router.post(
    "/{job_card_id}/start-testing",
    response_model=JobCardResponse,
)
def start_testing(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "TESTING",
    )


@router.post(
    "/{job_card_id}/complete",
    response_model=JobCardResponse,
)
def complete_job(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "COMPLETED",
    )


@router.post(
    "/{job_card_id}/ready-for-delivery",
    response_model=JobCardResponse,
)
def ready_for_delivery(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "READY_FOR_DELIVERY",
    )


@router.post(
    "/{job_card_id}/cancel",
    response_model=JobCardResponse,
)
def cancel_job(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "CANCELLED",
    )
