from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.customer_product import CustomerProduct
from app.models.customer import Customer
from app.schemas.customer_product import CustomerProductCreate



def create_customer_product(
    db: Session,
    product_data: CustomerProductCreate
):

    # Check customer exists

    customer = (
        db.query(Customer)
        .filter(
            Customer.id == product_data.customer_id
        )
        .first()
    )


    if not customer:

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Customer not found"
        )


    # Check duplicate serial number

    if product_data.serial_number:

        existing_product = (
            db.query(CustomerProduct)
            .filter(
                CustomerProduct.serial_number == product_data.serial_number
            )
            .first()
        )


        if existing_product:

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Product with this serial number already exists"
            )


    new_product = CustomerProduct(

        customer_id=product_data.customer_id,

        brand=product_data.brand,

        product_name=product_data.product_name,

        model_number=product_data.model_number,

        serial_number=product_data.serial_number,

        purchase_date=product_data.purchase_date,

        warranty_status=product_data.warranty_status

    )


    db.add(new_product)

    db.commit()

    db.refresh(new_product)


    return new_product




def get_customer_products(
    db: Session,
    customer_id: int
):

    return (
        db.query(CustomerProduct)
        .filter(
            CustomerProduct.customer_id == customer_id
        )
        .all()
    )




def get_product_by_id(
    db: Session,
    product_id: int
):

    product = (
        db.query(CustomerProduct)
        .filter(
            CustomerProduct.id == product_id
        )
        .first()
    )


    if not product:

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found"
        )


    return product




def update_customer_product(
    db: Session,
    product_id: int,
    product_data: CustomerProductCreate
):

    product = get_product_by_id(
        db,
        product_id
    )


    product.brand = product_data.brand

    product.product_name = product_data.product_name

    product.model_number = product_data.model_number

    product.serial_number = product_data.serial_number

    product.purchase_date = product_data.purchase_date

    product.warranty_status = product_data.warranty_status


    db.commit()

    db.refresh(product)


    return product




def delete_customer_product(
    db: Session,
    product_id: int
):

    product = get_product_by_id(
        db,
        product_id
    )


    db.delete(product)

    db.commit()


    return {
        "message": "Customer product deleted successfully"
    }
