from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.auth.permissions import (
    get_active_user,
    require_roles,
)
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


manage_technicians = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
)


router = APIRouter(
    prefix="/api/v1/technicians",
    tags=["Technicians"],
    dependencies=[
        Depends(get_active_user),
    ],
)


@router.post(
    "/",
    response_model=TechnicianResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(manage_technicians),
    ],
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
    dependencies=[
        Depends(manage_technicians),
    ],
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
    dependencies=[
        Depends(manage_technicians),
    ],
)
def remove_technician(
    technician_id: int,
    db: Session = Depends(get_db),
):
    return deactivate_technician(
        db,
        technician_id,
    )
