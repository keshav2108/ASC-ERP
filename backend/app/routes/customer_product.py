from fastapi import (
    APIRouter,
    Depends,
    status,
)
from sqlalchemy.orm import Session

from app.auth.permissions import require_roles
from app.database import get_db
from app.schemas.customer_product import (
    CustomerProductCreate,
    CustomerProductResponse,
)
from app.services.customer_product_service import (
    create_customer_product,
    delete_customer_product,
    get_customer_products,
    get_product_by_id,
    update_customer_product,
)


customer_product_operations_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
)

customer_product_delete_access = require_roles(
    "ADMIN",
)


router = APIRouter(
    prefix="/api/v1/customer-products",
    tags=["Customer Products"],
    dependencies=[
        Depends(
            customer_product_operations_access
        ),
    ],
)


@router.post(
    "/",
    response_model=CustomerProductResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_customer_product(
    product: CustomerProductCreate,
    db: Session = Depends(get_db),
):
    return create_customer_product(
        db,
        product,
    )


@router.get(
    "/customer/{customer_id}",
    response_model=list[
        CustomerProductResponse
    ],
)
def list_customer_products(
    customer_id: int,
    db: Session = Depends(get_db),
):
    return get_customer_products(
        db,
        customer_id,
    )


@router.get(
    "/{product_id}",
    response_model=CustomerProductResponse,
)
def get_product(
    product_id: int,
    db: Session = Depends(get_db),
):
    return get_product_by_id(
        db,
        product_id,
    )


@router.put(
    "/{product_id}",
    response_model=CustomerProductResponse,
)
def edit_customer_product(
    product_id: int,
    product: CustomerProductCreate,
    db: Session = Depends(get_db),
):
    return update_customer_product(
        db,
        product_id,
        product,
    )


@router.delete(
    "/{product_id}",
    dependencies=[
        Depends(
            customer_product_delete_access
        ),
    ],
)
def remove_customer_product(
    product_id: int,
    db: Session = Depends(get_db),
):
    return delete_customer_product(
        db,
        product_id,
    )
