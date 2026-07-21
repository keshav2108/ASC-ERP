from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.customer_product import CustomerProduct
from app.models.service_request import ServiceRequest
from app.schemas.service_request import (
    RegisterComplaintCreate,
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


def _clean_optional_text(
    value: object | None,
) -> str | None:
    if value is None:
        return None

    text = str(value).strip()

    return text or None


def _apply_customer_details(
    customer: Customer,
    request_data: RegisterComplaintCreate,
) -> None:
    customer_data = request_data.customer

    customer.full_name = customer_data.full_name.strip()
    customer.mobile = customer_data.mobile.strip()
    customer.alternate_mobile = _clean_optional_text(
        customer_data.alternate_mobile
    )
    customer.email = _clean_optional_text(
        customer_data.email
    )
    customer.address = _clean_optional_text(
        customer_data.address
    )
    customer.city = _clean_optional_text(
        customer_data.city
    )
    customer.pincode = _clean_optional_text(
        customer_data.pincode
    )
    customer.status = "ACTIVE"


def _apply_product_details(
    customer_product: CustomerProduct,
    request_data: RegisterComplaintCreate,
) -> None:
    product_data = request_data.product

    customer_product.brand = product_data.brand.strip()
    customer_product.product_name = (
        product_data.product_name.strip()
    )
    customer_product.model_number = (
        _clean_optional_text(
            product_data.model_number
        )
    )
    customer_product.serial_number = (
        _clean_optional_text(
            product_data.serial_number
        )
    )
    customer_product.purchase_date = (
        product_data.purchase_date
    )
    customer_product.warranty_status = (
        product_data.warranty_status
        .strip()
        .upper()
    )


def register_customer_complaint(
    db: Session,
    request_data: RegisterComplaintCreate,
):
    customer_data = request_data.customer
    product_data = request_data.product
    complaint_data = request_data.complaint

    mobile = customer_data.mobile.strip()

    try:
        customer = (
            db.query(Customer)
            .filter(
                Customer.mobile == mobile
            )
            .first()
        )

        if customer is None:
            customer_count = (
                db.query(Customer).count()
            )

            customer = Customer(
                customer_code=generate_code(
                    "CUS",
                    customer_count + 1,
                ),
                full_name=(
                    customer_data.full_name.strip()
                ),
                mobile=mobile,
                alternate_mobile=(
                    _clean_optional_text(
                        customer_data.alternate_mobile
                    )
                ),
                email=_clean_optional_text(
                    customer_data.email
                ),
                address=_clean_optional_text(
                    customer_data.address
                ),
                city=_clean_optional_text(
                    customer_data.city
                ),
                pincode=_clean_optional_text(
                    customer_data.pincode
                ),
                status="ACTIVE",
            )

            db.add(customer)
            db.flush()

        else:
            _apply_customer_details(
                customer,
                request_data,
            )

            db.flush()

        customer_product = None

        if product_data.customer_product_id:
            customer_product = (
                db.query(CustomerProduct)
                .filter(
                    CustomerProduct.id
                    == product_data.customer_product_id,
                    CustomerProduct.customer_id
                    == customer.id,
                )
                .first()
            )

            if customer_product is None:
                raise HTTPException(
                    status_code=(
                        status.HTTP_400_BAD_REQUEST
                    ),
                    detail=(
                        "Selected registered product "
                        "does not belong to this customer"
                    ),
                )

            requested_serial = (
                _clean_optional_text(
                    product_data.serial_number
                )
            )

            if requested_serial:
                conflicting_product = (
                    db.query(CustomerProduct)
                    .filter(
                        CustomerProduct.serial_number
                        == requested_serial,
                        CustomerProduct.id
                        != customer_product.id,
                    )
                    .first()
                )

                if conflicting_product:
                    raise HTTPException(
                        status_code=(
                            status.HTTP_400_BAD_REQUEST
                        ),
                        detail=(
                            "Another product already uses "
                            "this serial number"
                        ),
                    )

            _apply_product_details(
                customer_product,
                request_data,
            )

            db.flush()

        else:
            requested_serial = (
                _clean_optional_text(
                    product_data.serial_number
                )
            )

            if requested_serial:
                serial_product = (
                    db.query(CustomerProduct)
                    .filter(
                        CustomerProduct.serial_number
                        == requested_serial
                    )
                    .first()
                )

                if serial_product:
                    if (
                        serial_product.customer_id
                        != customer.id
                    ):
                        raise HTTPException(
                            status_code=(
                                status.HTTP_400_BAD_REQUEST
                            ),
                            detail=(
                                "A product with this serial "
                                "number is registered to "
                                "another customer"
                            ),
                        )

                    customer_product = serial_product

                    _apply_product_details(
                        customer_product,
                        request_data,
                    )

                    db.flush()

            if customer_product is None:
                customer_product = CustomerProduct(
                    customer_id=customer.id,
                    brand=product_data.brand.strip(),
                    product_name=(
                        product_data.product_name.strip()
                    ),
                    model_number=(
                        _clean_optional_text(
                            product_data.model_number
                        )
                    ),
                    serial_number=requested_serial,
                    purchase_date=(
                        product_data.purchase_date
                    ),
                    warranty_status=(
                        product_data.warranty_status
                        .strip()
                        .upper()
                    ),
                )

                db.add(customer_product)
                db.flush()

        complaint_category = (
            validate_master_option(
                db,
                "COMPLAINT_CATEGORY",
                complaint_data.complaint_category,
            )
        )

        product_condition = (
            validate_master_option(
                db,
                "PRODUCT_CONDITION",
                complaint_data.product_condition,
            )
        )

        priority = validate_master_option(
            db,
            "PRIORITY",
            complaint_data.priority,
        )

        service_status = validate_master_option(
            db,
            "SERVICE_STATUS",
            "OPEN",
        )

        request_count = (
            db.query(ServiceRequest).count()
        )

        service_request = ServiceRequest(
            request_code=generate_code(
                "SR",
                request_count + 1,
            ),
            customer_id=customer.id,
            customer_product_id=(
                customer_product.id
            ),
            complaint_category=(
                complaint_category
            ),
            complaint_description=(
                complaint_data
                .complaint_description
                .strip()
            ),
            received_accessories=(
                _clean_optional_text(
                    complaint_data
                    .received_accessories
                )
            ),
            product_condition=(
                product_condition
            ),
            priority=priority,
            status=service_status,
            estimated_delivery=(
                complaint_data.estimated_delivery
            ),
        )

        db.add(service_request)
        db.flush()
        db.commit()

        db.refresh(service_request)

        # Load the relationships before returning the
        # response to FastAPI/Pydantic.
        service_request.customer
        service_request.customer_product

        return service_request

    except HTTPException:
        db.rollback()
        raise

    except IntegrityError as error:
        db.rollback()

        database_message = str(
            error.orig
        ).lower()

        if "serial" in database_message:
            detail = (
                "A product with this serial number "
                "already exists"
            )

        elif "mobile" in database_message:
            detail = (
                "A customer with this mobile number "
                "already exists"
            )

        else:
            detail = (
                "Complaint registration failed because "
                "duplicate data already exists"
            )

        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=detail,
        ) from error

    except Exception:
        db.rollback()
        raise


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
