from decimal import Decimal, ROUND_HALF_UP

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.invoice import Invoice
from app.models.payment import Payment
from app.schemas.payment import PaymentCreate
from app.utils.payment_code_generator import (
    generate_payment_code,
)


MONEY_PLACES = Decimal("0.01")

ALLOWED_PAYMENT_METHODS = {
    "CASH",
    "UPI",
    "CARD",
    "BANK_TRANSFER",
}


def money(
    value: Decimal | int | float | str,
) -> Decimal:
    return Decimal(str(value)).quantize(
        MONEY_PLACES,
        rounding=ROUND_HALF_UP,
    )


def get_payment_by_id(
    db: Session,
    payment_id: int,
):
    payment = (
        db.query(Payment)
        .filter(Payment.id == payment_id)
        .first()
    )

    if not payment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment not found",
        )

    return payment


def get_successful_paid_amount(
    db: Session,
    invoice_id: int,
) -> Decimal:
    paid_amount = (
        db.query(
            func.coalesce(
                func.sum(Payment.amount),
                0,
            )
        )
        .filter(
            Payment.invoice_id == invoice_id,
            Payment.status == "SUCCESS",
        )
        .scalar()
    )

    return money(paid_amount)


def update_invoice_payment_status(
    db: Session,
    invoice: Invoice,
):
    total_amount = money(
        invoice.total_amount
    )

    paid_amount = get_successful_paid_amount(
        db,
        invoice.id,
    )

    if paid_amount <= 0:
        invoice.payment_status = "UNPAID"

    elif paid_amount < total_amount:
        invoice.payment_status = "PARTIALLY_PAID"

    else:
        invoice.payment_status = "PAID"


def create_payment(
    db: Session,
    payment_data: PaymentCreate,
):
    invoice = (
        db.query(Invoice)
        .filter(
            Invoice.id == payment_data.invoice_id
        )
        .first()
    )

    if not invoice:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invoice not found",
        )

    if invoice.status == "CANCELLED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Payment cannot be added to "
                "a cancelled invoice"
            ),
        )

    payment_method = (
        payment_data.payment_method
        .strip()
        .upper()
        .replace(" ", "_")
    )

    if payment_method not in ALLOWED_PAYMENT_METHODS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Invalid payment method. Allowed: "
                "CASH, UPI, CARD, BANK_TRANSFER"
            ),
        )

    total_amount = money(
        invoice.total_amount
    )

    paid_amount = get_successful_paid_amount(
        db,
        invoice.id,
    )

    balance_amount = money(
        total_amount - paid_amount
    )

    payment_amount = money(
        payment_data.amount
    )

    if balance_amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invoice is already fully paid",
        )

    if payment_amount > balance_amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Payment exceeds balance amount. "
                f"Remaining balance: {balance_amount}"
            ),
        )

    last_payment_id = (
        db.query(func.max(Payment.id))
        .scalar()
        or 0
    )

    payment = Payment(
        payment_code=generate_payment_code(
            last_payment_id + 1
        ),
        invoice_id=invoice.id,
        amount=payment_amount,
        payment_method=payment_method,
        transaction_reference=(
            payment_data.transaction_reference
        ),
        remarks=payment_data.remarks,
        status="SUCCESS",
    )

    db.add(payment)

    try:
        db.flush()

        update_invoice_payment_status(
            db,
            invoice,
        )

        db.commit()
        db.refresh(payment)

    except Exception:
        db.rollback()
        raise

    return payment


def get_payments(
    db: Session,
):
    return (
        db.query(Payment)
        .order_by(Payment.id.desc())
        .all()
    )


def get_invoice_payments(
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

    payments = (
        db.query(Payment)
        .filter(
            Payment.invoice_id == invoice_id
        )
        .order_by(Payment.id.desc())
        .all()
    )

    paid_amount = get_successful_paid_amount(
        db,
        invoice_id,
    )

    total_amount = money(
        invoice.total_amount
    )

    balance_amount = money(
        total_amount - paid_amount
    )

    if balance_amount < 0:
        balance_amount = Decimal("0.00")

    return {
        "invoice_id": invoice.id,
        "invoice_code": invoice.invoice_code,
        "total_amount": total_amount,
        "paid_amount": paid_amount,
        "balance_amount": balance_amount,
        "payment_status": invoice.payment_status,
        "payments": payments,
    }


def cancel_payment(
    db: Session,
    payment_id: int,
):
    payment = get_payment_by_id(
        db,
        payment_id,
    )

    if payment.status == "CANCELLED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Payment is already cancelled",
        )

    invoice = payment.invoice

    payment.status = "CANCELLED"

    try:
        db.flush()

        update_invoice_payment_status(
            db,
            invoice,
        )

        db.commit()
        db.refresh(payment)

    except Exception:
        db.rollback()
        raise

    return payment
