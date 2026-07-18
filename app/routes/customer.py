from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.customer import CustomerCreate, CustomerResponse
from app.services.customer_service import (
    create_customer,
    get_customers,
    get_customer_by_id,
    update_customer,
    delete_customer
)


router = APIRouter(
    prefix="/api/v1/customers",
    tags=["Customers"]
)



# Create Customer
@router.post(
    "/",
    response_model=CustomerResponse
)
def add_customer(
    customer: CustomerCreate,
    db: Session = Depends(get_db)
):

    return create_customer(
        db,
        customer
    )



# Get All Customers
@router.get(
    "/",
    response_model=list[CustomerResponse]
)
def list_customers(
    db: Session = Depends(get_db)
):

    return get_customers(
        db
    )



# Get Customer By ID
@router.get(
    "/{customer_id}",
    response_model=CustomerResponse
)
def get_customer(
    customer_id: int,
    db: Session = Depends(get_db)
):

    return get_customer_by_id(
        db,
        customer_id
    )



# Update Customer
@router.put(
    "/{customer_id}",
    response_model=CustomerResponse
)
def edit_customer(
    customer_id: int,
    customer: CustomerCreate,
    db: Session = Depends(get_db)
):

    return update_customer(
        db,
        customer_id,
        customer
    )



# Delete Customer (Soft Delete)
@router.delete(
    "/{customer_id}"
)
def remove_customer(
    customer_id: int,
    db: Session = Depends(get_db)
):

    return delete_customer(
        db,
        customer_id
    )
