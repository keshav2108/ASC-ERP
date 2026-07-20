from fastapi import (
    APIRouter,
    Depends,
    status,
)
from sqlalchemy.orm import Session

from app.auth.permissions import require_roles
from app.database import get_db
from app.schemas.payment import (
    InvoicePaymentSummary,
    PaymentCreate,
    PaymentResponse,
)
from app.services.payment_service import (
    cancel_payment,
    create_payment,
    get_invoice_payments,
    get_payment_by_id,
    get_payments,
)


payment_view_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "ACCOUNTANT",
)

payment_manage_access = require_roles(
    "ADMIN",
    "ACCOUNTANT",
)


router = APIRouter(
    prefix="/api/v1/payments",
    tags=["Payments"],
)


@router.post(
    "/",
    response_model=PaymentResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(payment_manage_access),
    ],
)
def add_payment(
    payment_data: PaymentCreate,
    db: Session = Depends(get_db),
):
    return create_payment(
        db,
        payment_data,
    )


@router.get(
    "/",
    response_model=list[PaymentResponse],
    dependencies=[
        Depends(payment_view_access),
    ],
)
def list_payments(
    db: Session = Depends(get_db),
):
    return get_payments(db)


@router.get(
    "/invoice/{invoice_id}",
    response_model=InvoicePaymentSummary,
    dependencies=[
        Depends(payment_view_access),
    ],
)
def list_invoice_payments(
    invoice_id: int,
    db: Session = Depends(get_db),
):
    return get_invoice_payments(
        db,
        invoice_id,
    )


@router.get(
    "/{payment_id}",
    response_model=PaymentResponse,
    dependencies=[
        Depends(payment_view_access),
    ],
)
def get_payment(
    payment_id: int,
    db: Session = Depends(get_db),
):
    return get_payment_by_id(
        db,
        payment_id,
    )


@router.post(
    "/{payment_id}/cancel",
    response_model=PaymentResponse,
    dependencies=[
        Depends(payment_manage_access),
    ],
)
def cancel_recorded_payment(
    payment_id: int,
    db: Session = Depends(get_db),
):
    return cancel_payment(
        db,
        payment_id,
    )
