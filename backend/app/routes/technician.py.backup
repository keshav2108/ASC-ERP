from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.technician import (
    TechnicianCreate,
    TechnicianResponse,
    TechnicianUpdate,
)
from app.services.technician_service import (
    create_technician,
    deactivate_technician,
    get_technician_by_id,
    get_technicians,
    update_technician,
)


router = APIRouter(
    prefix="/api/v1/technicians",
    tags=["Technicians"],
)


@router.post(
    "/",
    response_model=TechnicianResponse,
    status_code=201,
)
def add_technician(
    technician_data: TechnicianCreate,
    db: Session = Depends(get_db),
):
    return create_technician(
        db,
        technician_data,
    )


@router.get(
    "/",
    response_model=list[TechnicianResponse],
)
def list_technicians(
    db: Session = Depends(get_db),
):
    return get_technicians(db)


@router.get(
    "/{technician_id}",
    response_model=TechnicianResponse,
)
def get_technician(
    technician_id: int,
    db: Session = Depends(get_db),
):
    return get_technician_by_id(
        db,
        technician_id,
    )


@router.patch(
    "/{technician_id}",
    response_model=TechnicianResponse,
)
def edit_technician(
    technician_id: int,
    technician_data: TechnicianUpdate,
    db: Session = Depends(get_db),
):
    return update_technician(
        db,
        technician_id,
        technician_data,
    )


@router.delete(
    "/{technician_id}",
)
def remove_technician(
    technician_id: int,
    db: Session = Depends(get_db),
):
    return deactivate_technician(
        db,
        technician_id,
    )
