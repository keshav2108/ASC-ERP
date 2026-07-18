from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.master_option import (
    MasterOptionCreate,
    MasterOptionResponse,
    MasterOptionUpdate,
)
from app.services.master_option_service import (
    create_master_option,
    deactivate_master_option,
    get_master_option_by_id,
    get_master_options,
    update_master_option,
)


router = APIRouter(
    prefix="/api/v1/master-options",
    tags=["Master Options"],
)


@router.post(
    "/",
    response_model=MasterOptionResponse,
    status_code=201,
)
def add_master_option(
    option_data: MasterOptionCreate,
    db: Session = Depends(get_db),
):
    return create_master_option(
        db,
        option_data,
    )


@router.get(
    "/type/{option_type}",
    response_model=list[MasterOptionResponse],
)
def list_master_options(
    option_type: str,
    include_inactive: bool = Query(False),
    db: Session = Depends(get_db),
):
    return get_master_options(
        db,
        option_type,
        include_inactive,
    )


@router.get(
    "/{option_id}",
    response_model=MasterOptionResponse,
)
def get_master_option(
    option_id: int,
    db: Session = Depends(get_db),
):
    return get_master_option_by_id(
        db,
        option_id,
    )


@router.patch(
    "/{option_id}",
    response_model=MasterOptionResponse,
)
def edit_master_option(
    option_id: int,
    option_data: MasterOptionUpdate,
    db: Session = Depends(get_db),
):
    return update_master_option(
        db,
        option_id,
        option_data,
    )


@router.delete(
    "/{option_id}",
)
def remove_master_option(
    option_id: int,
    db: Session = Depends(get_db),
):
    return deactivate_master_option(
        db,
        option_id,
    )
