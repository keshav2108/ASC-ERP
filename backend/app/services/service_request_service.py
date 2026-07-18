from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.customer_product import CustomerProduct
from app.models.service_request import ServiceRequest
from app.schemas.service_request import (
    ServiceRequestCreate,
    ServiceRequestUpdate,
)
from app.services.master_validation_service import (
    validate_master_option,
)
from app.utils.id_generator import generate_code


def get_service_request_by_id(
    db: Session,
    service_request_id: int,
):
    service_request = (
        db.query(ServiceRequest)
        .filter(
            ServiceRequest.id == service_request_id
        )
        .first()
    )

    if not service_request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service request not found",
        )

    return service_request


def create_service_request(
    db: Session,
    request_data: ServiceRequestCreate,
):
    customer = (
        db.query(Customer)
        .filter(
            Customer.id == request_data.customer_id,
            Customer.status == "ACTIVE",
        )
        .first()
    )

    if not customer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active customer not found",
        )

    customer_product = (
        db.query(CustomerProduct)
        .filter(
            CustomerProduct.id
            == request_data.customer_product_id,
            CustomerProduct.customer_id
            == request_data.customer_id,
        )
        .first()
    )

    if not customer_product:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Selected product does not belong "
                "to this customer"
            ),
        )

    complaint_category = validate_master_option(
        db,
        "COMPLAINT_CATEGORY",
        request_data.complaint_category,
    )

    product_condition = validate_master_option(
        db,
        "PRODUCT_CONDITION",
        request_data.product_condition,
    )

    priority = validate_master_option(
        db,
        "PRIORITY",
        request_data.priority,
    )

    service_status = validate_master_option(
        db,
        "SERVICE_STATUS",
        "OPEN",
    )

    request_count = db.query(ServiceRequest).count()

    request_code = generate_code(
        "SR",
        request_count + 1,
    )

    service_request = ServiceRequest(
        request_code=request_code,
        customer_id=request_data.customer_id,
        customer_product_id=(
            request_data.customer_product_id
        ),
        complaint_category=complaint_category,
        complaint_description=(
            request_data.complaint_description
        ),
        received_accessories=(
            request_data.received_accessories
        ),
        product_condition=product_condition,
        priority=priority,
        status=service_status,
        estimated_delivery=(
            request_data.estimated_delivery
        ),
    )

    db.add(service_request)

    try:
        db.commit()
        db.refresh(service_request)

    except Exception:
        db.rollback()
        raise

    return service_request


def get_service_requests(
    db: Session,
):
    return (
        db.query(ServiceRequest)
        .order_by(ServiceRequest.id.desc())
        .all()
    )


def get_customer_service_requests(
    db: Session,
    customer_id: int,
):
    return (
        db.query(ServiceRequest)
        .filter(
            ServiceRequest.customer_id == customer_id
        )
        .order_by(ServiceRequest.id.desc())
        .all()
    )


def get_product_service_requests(
    db: Session,
    customer_product_id: int,
):
    return (
        db.query(ServiceRequest)
        .filter(
            ServiceRequest.customer_product_id
            == customer_product_id
        )
        .order_by(ServiceRequest.id.desc())
        .all()
    )


def update_service_request(
    db: Session,
    service_request_id: int,
    request_data: ServiceRequestUpdate,
):
    service_request = get_service_request_by_id(
        db,
        service_request_id,
    )

    update_data = request_data.model_dump(
        exclude_unset=True
    )

    validation_mapping = {
        "complaint_category": "COMPLAINT_CATEGORY",
        "product_condition": "PRODUCT_CONDITION",
        "priority": "PRIORITY",
        "status": "SERVICE_STATUS",
    }

    for field, value in update_data.items():

        if (
            field in validation_mapping
            and value is not None
        ):
            value = validate_master_option(
                db,
                validation_mapping[field],
                value,
            )

        setattr(
            service_request,
            field,
            value,
        )

    try:
        db.commit()
        db.refresh(service_request)

    except Exception:
        db.rollback()
        raise

    return service_request


def cancel_service_request(
    db: Session,
    service_request_id: int,
):
    service_request = get_service_request_by_id(
        db,
        service_request_id,
    )

    if service_request.status == "DELIVERED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Delivered service request "
                "cannot be cancelled"
            ),
        )

    cancelled_status = validate_master_option(
        db,
        "SERVICE_STATUS",
        "CANCELLED",
    )

    service_request.status = cancelled_status

    db.commit()
    db.refresh(service_request)

    return {
        "message": (
            "Service request cancelled successfully"
        ),
        "request_code": service_request.request_code,
    }
