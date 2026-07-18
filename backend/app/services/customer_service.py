from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.schemas.customer import CustomerCreate
from app.utils.id_generator import generate_code



def create_customer(
    db: Session,
    customer_data: CustomerCreate
):

    existing_customer = (
        db.query(Customer)
        .filter(
            Customer.mobile == customer_data.mobile
        )
        .first()
    )


    if existing_customer:

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Customer with this mobile number already exists"
        )


    count = db.query(Customer).count()


    customer_code = generate_code(
        "CUS",
        count + 1
    )


    new_customer = Customer(

        customer_code=customer_code,

        full_name=customer_data.full_name,

        mobile=customer_data.mobile,

        alternate_mobile=customer_data.alternate_mobile,

        email=customer_data.email,

        address=customer_data.address,

        city=customer_data.city,

        pincode=customer_data.pincode

    )


    db.add(new_customer)

    db.commit()

    db.refresh(new_customer)


    return new_customer




def get_customers(
    db: Session
):

    return (
        db.query(Customer)
        .filter(
            Customer.status == "ACTIVE"
        )
        .all()
    )




def get_customer_by_id(
    db: Session,
    customer_id: int
):

    customer = (
        db.query(Customer)
        .filter(
            Customer.id == customer_id
        )
        .first()
    )


    if not customer:

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Customer not found"
        )


    return customer




def update_customer(
    db: Session,
    customer_id: int,
    customer_data: CustomerCreate
):

    customer = get_customer_by_id(
        db,
        customer_id
    )


    customer.full_name = customer_data.full_name

    customer.mobile = customer_data.mobile

    customer.alternate_mobile = customer_data.alternate_mobile

    customer.email = customer_data.email

    customer.address = customer_data.address

    customer.city = customer_data.city

    customer.pincode = customer_data.pincode


    db.commit()

    db.refresh(customer)


    return customer




def delete_customer(
    db: Session,
    customer_id: int
):

    customer = get_customer_by_id(
        db,
        customer_id
    )


    customer.status = "INACTIVE"


    db.commit()

    db.refresh(customer)


    return {
        "message": "Customer deactivated successfully"
    }
