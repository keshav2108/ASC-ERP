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


master_option_view_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
    "TECHNICIAN",
    "ACCOUNTANT",
)

master_option_admin_access = require_roles(
    "ADMIN",
)


router = APIRouter(
    prefix="/api/v1/master-options",
    tags=["Master Options"],
)


@router.post(
    "/",
    response_model=MasterOptionResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(master_option_admin_access),
    ],
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
    current_user: User = Depends(
        master_option_view_access
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
                "Only an Admin can view inactive "
                "Master Options"
            ),
        )

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
    _current_user: User = Depends(
        master_option_view_access
    ),
):
    return get_master_option_by_id(
        db,
        option_id,
    )


@router.patch(
    "/{option_id}",
    response_model=MasterOptionResponse,
    dependencies=[
        Depends(master_option_admin_access),
    ],
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
    dependencies=[
        Depends(master_option_admin_access),
    ],
)
def remove_master_option(
    option_id: int,
    db: Session = Depends(get_db),
):
    return deactivate_master_option(
        db,
        option_id,
    )
