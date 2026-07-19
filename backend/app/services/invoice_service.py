from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.invoice import Invoice
from app.models.invoice_item import InvoiceItem
from app.models.job_card import JobCard
from app.models.stock_transaction import StockTransaction
from app.schemas.invoice import InvoiceCreate
from app.utils.invoice_code_generator import (
    generate_invoice_code,
)


MONEY_PLACES = Decimal("0.01")


def money(
    value: Decimal | int | float | str,
) -> Decimal:
    return Decimal(str(value)).quantize(
        MONEY_PLACES,
        rounding=ROUND_HALF_UP,
    )


def get_invoice_by_id(
    db: Session,
    invoice_id: int,
):
    invoice = (
        db.query(Invoice)
        .filter(Invoice.id == invoice_id)
        .first()
    )

    if not invoice:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invoice not found",
        )

    return invoice


def get_invoice_by_job_card(
    db: Session,
    job_card_id: int,
):
    invoice = (
        db.query(Invoice)
        .filter(
            Invoice.job_card_id == job_card_id
        )
        .first()
    )

    if not invoice:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invoice not found for this job card",
        )

    return invoice


def get_invoices(
    db: Session,
):
    return (
        db.query(Invoice)
        .order_by(Invoice.id.desc())
        .all()
    )


def create_invoice(
    db: Session,
    invoice_data: InvoiceCreate,
):
    job_card = (
        db.query(JobCard)
        .filter(
            JobCard.id == invoice_data.job_card_id
        )
        .first()
    )

    if not job_card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Job card not found",
        )

    if job_card.status not in {
        "COMPLETED",
        "READY_FOR_DELIVERY",
    }:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Invoice can only be generated for a "
                "completed or ready-for-delivery job card"
            ),
        )

    existing_invoice = (
        db.query(Invoice)
        .filter(
            Invoice.job_card_id
            == invoice_data.job_card_id
        )
        .first()
    )

    if existing_invoice:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Invoice already exists for this job card"
            ),
        )

    service_request = job_card.service_request

    if not service_request:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Service request is not linked "
                "to this job card"
            ),
        )

    labour_amount = money(
        job_card.labour_charge or 0
    )

    part_totals = defaultdict(
        lambda: {
            "spare_part": None,
            "quantity": 0,
            "total": Decimal("0.00"),
        }
    )

    transactions = (
        db.query(StockTransaction)
        .filter(
            StockTransaction.job_card_id
            == invoice_data.job_card_id,
            StockTransaction.transaction_type.in_(
                ["ISSUE", "RETURN"]
            ),
        )
        .order_by(StockTransaction.id.asc())
        .all()
    )

    for transaction in transactions:
        part_data = part_totals[
            transaction.spare_part_id
        ]

        part_data["spare_part"] = (
            transaction.spare_part
        )

        transaction_quantity = (
            transaction.quantity
        )

        transaction_total = money(
            transaction.line_total or 0
        )

        if transaction.transaction_type == "ISSUE":
            part_data["quantity"] += (
                transaction_quantity
            )
            part_data["total"] += (
                transaction_total
            )

        elif transaction.transaction_type == "RETURN":
            part_data["quantity"] -= (
                transaction_quantity
            )
            part_data["total"] -= (
                transaction_total
            )

    invoice_part_items = []
    parts_amount = Decimal("0.00")

    for spare_part_id, part_data in part_totals.items():
        net_quantity = part_data["quantity"]
        net_total = money(part_data["total"])

        if net_quantity <= 0:
            continue

        if net_total < 0:
            net_total = Decimal("0.00")

        unit_price = money(
            net_total / net_quantity
        )

        spare_part = part_data["spare_part"]

        description = (
            spare_part.part_name
            if spare_part
            else f"Spare Part {spare_part_id}"
        )

        invoice_part_items.append(
            {
                "spare_part_id": spare_part_id,
                "item_type": "SPARE_PART",
                "description": description,
                "quantity": net_quantity,
                "unit_price": unit_price,
                "total_price": net_total,
            }
        )

        parts_amount += net_total

    parts_amount = money(parts_amount)

    subtotal = money(
        labour_amount + parts_amount
    )

    discount_amount = money(
        invoice_data.discount_amount
    )

    if discount_amount > subtotal:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Discount amount cannot exceed subtotal"
            ),
        )

    taxable_amount = money(
        subtotal - discount_amount
    )

    gst_percentage = money(
        invoice_data.gst_percentage
    )

    gst_amount = money(
        taxable_amount
        * gst_percentage
        / Decimal("100")
    )

    total_amount = money(
        taxable_amount + gst_amount
    )

    last_invoice_id = (
        db.query(func.max(Invoice.id))
        .scalar()
        or 0
    )

    invoice = Invoice(
        invoice_code=generate_invoice_code(
            last_invoice_id + 1
        ),
        job_card_id=job_card.id,
        customer_id=service_request.customer_id,
        labour_amount=labour_amount,
        parts_amount=parts_amount,
        subtotal=subtotal,
        discount_amount=discount_amount,
        taxable_amount=taxable_amount,
        gst_percentage=gst_percentage,
        gst_amount=gst_amount,
        total_amount=total_amount,
        payment_status="UNPAID",
        status="GENERATED",
    )

    db.add(invoice)

    try:
        db.flush()

        if labour_amount > 0:
            labour_item = InvoiceItem(
                invoice_id=invoice.id,
                spare_part_id=None,
                item_type="LABOUR",
                description="Labour Charge",
                quantity=1,
                unit_price=labour_amount,
                total_price=labour_amount,
            )

            db.add(labour_item)

        for part_item in invoice_part_items:
            invoice_item = InvoiceItem(
                invoice_id=invoice.id,
                spare_part_id=(
                    part_item["spare_part_id"]
                ),
                item_type=part_item["item_type"],
                description=part_item["description"],
                quantity=part_item["quantity"],
                unit_price=part_item["unit_price"],
                total_price=part_item["total_price"],
            )

            db.add(invoice_item)

        db.commit()
        db.refresh(invoice)

    except Exception:
        db.rollback()
        raise

    return invoice


def cancel_invoice(
    db: Session,
    invoice_id: int,
):
    invoice = get_invoice_by_id(
        db,
        invoice_id,
    )

    if invoice.payment_status in {
        "PARTIALLY_PAID",
        "PAID",
    }:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Paid or partially paid invoice "
                "cannot be cancelled"
            ),
        )

    if invoice.status == "CANCELLED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invoice is already cancelled",
        )

    invoice.status = "CANCELLED"

    try:
        db.commit()
        db.refresh(invoice)

    except Exception:
        db.rollback()
        raise

    return invoice
