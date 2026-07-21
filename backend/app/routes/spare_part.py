from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    status,
)
from sqlalchemy.orm import Session

from app.auth.permissions import (
    normalize_role,
    require_roles,
)
from app.database import get_db
from app.models.user import User
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


spare_part_view_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "ACCOUNTANT",
)

spare_part_selection_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "ACCOUNTANT",
    "TECHNICIAN",
)

spare_part_manage_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
)


router = APIRouter(
    prefix="/api/v1/spare-parts",
    tags=["Spare Parts"],
)


@router.post(
    "/",
    response_model=SparePartResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(spare_part_manage_access),
    ],
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
    current_user: User = Depends(
        spare_part_selection_access
    ),
):
    if (
        include_inactive
        and normalize_role(current_user.role)
        != "ADMIN"
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Only Admin can view inactive "
                "spare parts"
            ),
        )

    return get_spare_parts(
        db,
        include_inactive,
    )


@router.get(
    "/low-stock",
    response_model=list[SparePartResponse],
    dependencies=[
        Depends(spare_part_view_access),
    ],
)
def list_low_stock_parts(
    db: Session = Depends(get_db),
):
    return get_low_stock_parts(db)


@router.get(
    "/{spare_part_id}",
    response_model=SparePartResponse,
    dependencies=[
        Depends(spare_part_view_access),
    ],
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
    dependencies=[
        Depends(spare_part_manage_access),
    ],
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
    dependencies=[
        Depends(spare_part_manage_access),
    ],
)
def remove_spare_part(
    spare_part_id: int,
    db: Session = Depends(get_db),
):
    return deactivate_spare_part(
        db,
        spare_part_id,
    )
