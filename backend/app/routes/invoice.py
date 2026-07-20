from fastapi import (
    APIRouter,
    Depends,
    status,
)
from sqlalchemy.orm import Session

from app.auth.permissions import require_roles
from app.database import get_db
from app.schemas.invoice import (
    InvoiceCreate,
    InvoiceResponse,
)
from app.services.invoice_service import (
    cancel_invoice,
    create_invoice,
    get_invoice_by_id,
    get_invoice_by_job_card,
    get_invoices,
)


invoice_view_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
    "ACCOUNTANT",
)

invoice_manage_access = require_roles(
    "ADMIN",
    "ACCOUNTANT",
)


router = APIRouter(
    prefix="/api/v1/invoices",
    tags=["Invoices"],
)


@router.post(
    "/",
    response_model=InvoiceResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(invoice_manage_access),
    ],
)
def generate_invoice(
    invoice_data: InvoiceCreate,
    db: Session = Depends(get_db),
):
    return create_invoice(
        db,
        invoice_data,
    )


@router.get(
    "/",
    response_model=list[InvoiceResponse],
    dependencies=[
        Depends(invoice_view_access),
    ],
)
def list_invoices(
    db: Session = Depends(get_db),
):
    return get_invoices(db)


@router.get(
    "/job-card/{job_card_id}",
    response_model=InvoiceResponse,
    dependencies=[
        Depends(invoice_view_access),
    ],
)
def get_job_card_invoice(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return get_invoice_by_job_card(
        db,
        job_card_id,
    )


@router.get(
    "/{invoice_id}",
    response_model=InvoiceResponse,
    dependencies=[
        Depends(invoice_view_access),
    ],
)
def get_invoice(
    invoice_id: int,
    db: Session = Depends(get_db),
):
    return get_invoice_by_id(
        db,
        invoice_id,
    )


@router.post(
    "/{invoice_id}/cancel",
    response_model=InvoiceResponse,
    dependencies=[
        Depends(invoice_manage_access),
    ],
)
def cancel_generated_invoice(
    invoice_id: int,
    db: Session = Depends(get_db),
):
    return cancel_invoice(
        db,
        invoice_id,
    )
