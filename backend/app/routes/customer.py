from fastapi import (
    APIRouter,
    Depends,
    status,
)
from sqlalchemy.orm import Session

from app.auth.permissions import require_roles
from app.database import get_db
from app.schemas.customer import (
    CustomerCreate,
    CustomerResponse,
)
from app.services.customer_service import (
    create_customer,
    delete_customer,
    get_customer_by_id,
    get_customers,
    update_customer,
)


customer_operations_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
)

customer_delete_access = require_roles(
    "ADMIN",
)


router = APIRouter(
    prefix="/api/v1/customers",
    tags=["Customers"],
    dependencies=[
        Depends(customer_operations_access),
    ],
)


@router.post(
    "/",
    response_model=CustomerResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_customer(
    customer: CustomerCreate,
    db: Session = Depends(get_db),
):
    return create_customer(
        db,
        customer,
    )


@router.get(
    "/",
    response_model=list[CustomerResponse],
)
def list_customers(
    db: Session = Depends(get_db),
):
    return get_customers(db)


@router.get(
    "/{customer_id}",
    response_model=CustomerResponse,
)
def get_customer(
    customer_id: int,
    db: Session = Depends(get_db),
):
    return get_customer_by_id(
        db,
        customer_id,
    )


@router.put(
    "/{customer_id}",
    response_model=CustomerResponse,
)
def edit_customer(
    customer_id: int,
    customer: CustomerCreate,
    db: Session = Depends(get_db),
):
    return update_customer(
        db,
        customer_id,
        customer,
    )


@router.delete(
    "/{customer_id}",
    dependencies=[
        Depends(customer_delete_access),
    ],
)
def remove_customer(
    customer_id: int,
    db: Session = Depends(get_db),
):
    return delete_customer(
        db,
        customer_id,
    )
