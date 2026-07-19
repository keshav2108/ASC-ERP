from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.spare_part import (
    SparePartCreate,
    SparePartResponse,
    SparePartUpdate,
)
from app.services.spare_part_service import (
    create_spare_part,
    deactivate_spare_part,
    get_low_stock_parts,
    get_spare_part_by_id,
    get_spare_parts,
    update_spare_part,
)


router = APIRouter(
    prefix="/api/v1/spare-parts",
    tags=["Spare Parts"],
)


@router.post(
    "/",
    response_model=SparePartResponse,
    status_code=201,
)
def add_spare_part(
    part_data: SparePartCreate,
    db: Session = Depends(get_db),
):
    return create_spare_part(
        db,
        part_data,
    )


@router.get(
    "/",
    response_model=list[SparePartResponse],
)
def list_spare_parts(
    include_inactive: bool = Query(False),
    db: Session = Depends(get_db),
):
    return get_spare_parts(
        db,
        include_inactive,
    )


@router.get(
    "/low-stock",
    response_model=list[SparePartResponse],
)
def list_low_stock_parts(
    db: Session = Depends(get_db),
):
    return get_low_stock_parts(db)


@router.get(
    "/{spare_part_id}",
    response_model=SparePartResponse,
)
def get_spare_part(
    spare_part_id: int,
    db: Session = Depends(get_db),
):
    return get_spare_part_by_id(
        db,
        spare_part_id,
    )


@router.patch(
    "/{spare_part_id}",
    response_model=SparePartResponse,
)
def edit_spare_part(
    spare_part_id: int,
    part_data: SparePartUpdate,
    db: Session = Depends(get_db),
):
    return update_spare_part(
        db,
        spare_part_id,
        part_data,
    )


@router.delete(
    "/{spare_part_id}",
)
def remove_spare_part(
    spare_part_id: int,
    db: Session = Depends(get_db),
):
    return deactivate_spare_part(
        db,
        spare_part_id,
    )
