from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)
from sqlalchemy.orm import Session

from app.auth.permissions import (
    normalize_role,
    require_roles,
)
from app.database import get_db
from app.models.user import User
from app.schemas.job_card import (
    JobCardResponse,
    TechnicianAssignmentCreate,
)
from app.schemas.service_request import (
    ServiceRequestCreate,
    ServiceRequestResponse,
    ServiceRequestUpdate,
)
from app.services.job_card_service import (
    assign_technician_and_create_job_card,
)
from app.services.service_request_service import (
    cancel_service_request,
    create_service_request,
    get_customer_service_requests,
    get_product_service_requests,
    get_service_request_by_id,
    get_service_requests,
    update_service_request,
)


service_operations_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
)

service_manager_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
)


router = APIRouter(
    prefix="/api/v1/service-requests",
    tags=["Service Requests"],
    dependencies=[
        Depends(service_operations_access),
    ],
)


@router.post(
    "/",
    response_model=ServiceRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_service_request(
    request_data: ServiceRequestCreate,
    db: Session = Depends(get_db),
):
    return create_service_request(
        db,
        request_data,
    )


@router.get(
    "/",
    response_model=list[ServiceRequestResponse],
)
def list_service_requests(
    db: Session = Depends(get_db),
):
    return get_service_requests(db)


@router.get(
    "/customer/{customer_id}",
    response_model=list[ServiceRequestResponse],
)
def list_customer_service_requests(
    customer_id: int,
    db: Session = Depends(get_db),
):
    return get_customer_service_requests(
        db,
        customer_id,
    )


@router.get(
    "/product/{customer_product_id}",
    response_model=list[ServiceRequestResponse],
)
def list_product_service_requests(
    customer_product_id: int,
    db: Session = Depends(get_db),
):
    return get_product_service_requests(
        db,
        customer_product_id,
    )


@router.get(
    "/{service_request_id}",
    response_model=ServiceRequestResponse,
)
def get_service_request(
    service_request_id: int,
    db: Session = Depends(get_db),
):
    return get_service_request_by_id(
        db,
        service_request_id,
    )


@router.patch(
    "/{service_request_id}",
    response_model=ServiceRequestResponse,
)
def edit_service_request(
    service_request_id: int,
    request_data: ServiceRequestUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        service_operations_access
    ),
):
    update_fields = request_data.model_dump(
        exclude_unset=True
    )

    current_role = normalize_role(
        current_user.role
    )

    if (
        current_role == "SERVICE_EXECUTIVE"
        and "status" in update_fields
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Service Executives cannot change "
                "the Service Request status"
            ),
        )

    return update_service_request(
        db,
        service_request_id,
        request_data,
    )


@router.delete(
    "/{service_request_id}",
    dependencies=[
        Depends(service_manager_access),
    ],
)
def cancel_request(
    service_request_id: int,
    db: Session = Depends(get_db),
):
    return cancel_service_request(
        db,
        service_request_id,
    )


@router.post(
    "/{service_request_id}/assign-technician",
    response_model=JobCardResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(service_manager_access),
    ],
)
def assign_technician(
    service_request_id: int,
    assignment_data: TechnicianAssignmentCreate,
    db: Session = Depends(get_db),
):
    return assign_technician_and_create_job_card(
        db,
        service_request_id,
        assignment_data,
    )
