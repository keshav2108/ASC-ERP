from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

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


router = APIRouter(
    prefix="/api/v1/invoices",
    tags=["Invoices"],
)


@router.post(
    "/",
    response_model=InvoiceResponse,
    status_code=201,
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
)
def list_invoices(
    db: Session = Depends(get_db),
):
    return get_invoices(db)


@router.get(
    "/job-card/{job_card_id}",
    response_model=InvoiceResponse,
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
)
def cancel_generated_invoice(
    invoice_id: int,
    db: Session = Depends(get_db),
):
    return cancel_invoice(
        db,
        invoice_id,
    )
