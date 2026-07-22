from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.job_card import JobCard
from app.models.spare_part import SparePart
from app.models.stock_transaction import StockTransaction
from app.schemas.stock_transaction import (
    StockAdjustmentCreate,
    StockInCreate,
    StockIssueCreate,
    StockReturnCreate,
)


def get_active_spare_part(
    db: Session,
    spare_part_id: int,
    *,
    lock_for_update: bool = False,
):
    query = (
        db.query(SparePart)
        .filter(
            SparePart.id == spare_part_id,
            SparePart.is_active.is_(True),
        )
    )

    if lock_for_update:
        query = (
            query
            .populate_existing()
            .with_for_update()
        )

    spare_part = query.first()

    if not spare_part:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active spare part not found",
        )

    return spare_part


def get_job_card(
    db: Session,
    job_card_id: int,
    *,
    lock_for_update: bool = False,
):
    query = (
        db.query(JobCard)
        .filter(JobCard.id == job_card_id)
    )

    if lock_for_update:
        query = (
            query
            .populate_existing()
            .with_for_update()
        )

    job_card = query.first()

    if not job_card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Job card not found",
        )

    return job_card


def stock_in(
    db: Session,
    stock_data: StockInCreate,
):
    spare_part = get_active_spare_part(
        db,
        stock_data.spare_part_id,
    )

    spare_part.current_stock += stock_data.quantity

    unit_price = spare_part.purchase_price
    line_total = unit_price * stock_data.quantity

    transaction = StockTransaction(
        spare_part_id=stock_data.spare_part_id,
        job_card_id=None,
        transaction_type="STOCK_IN",
        quantity=stock_data.quantity,
        unit_price=unit_price,
        line_total=line_total,
        reference=stock_data.reference,
        remarks=stock_data.remarks,
    )

    db.add(transaction)

    try:
        db.commit()
        db.refresh(transaction)

    except Exception:
        db.rollback()
        raise

    return transaction


def issue_stock_to_job_card(
    db: Session,
    issue_data: StockIssueCreate,
    *,
    commit: bool = True,
):
    spare_part = get_active_spare_part(
        db,
        issue_data.spare_part_id,
        lock_for_update=True,
    )

    job_card = get_job_card(
        db,
        issue_data.job_card_id,
        lock_for_update=True,
    )

    if job_card.status not in {
        "DIAGNOSIS",
        "REPAIR_IN_PROGRESS",
    }:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Spare parts can only be issued during "
                "diagnosis or repair"
            ),
        )

    if spare_part.current_stock < issue_data.quantity:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Insufficient stock. Available: "
                f"{spare_part.current_stock}"
            ),
        )

    spare_part.current_stock -= issue_data.quantity

    unit_price = spare_part.selling_price
    line_total = unit_price * issue_data.quantity

    transaction = StockTransaction(
        spare_part_id=issue_data.spare_part_id,
        job_card_id=issue_data.job_card_id,
        transaction_type="ISSUE",
        quantity=issue_data.quantity,
        unit_price=unit_price,
        line_total=line_total,
        reference=job_card.job_code,
        remarks=issue_data.remarks,
    )

    db.add(transaction)

    try:
        if commit:
            db.commit()
            db.refresh(transaction)
        else:
            db.flush()

    except Exception:
        db.rollback()
        raise

    return transaction


def return_stock_from_job_card(
    db: Session,
    return_data: StockReturnCreate,
    *,
    commit: bool = True,
):
    correction_reason = (
        return_data.remarks or ""
    ).strip()

    if len(correction_reason) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "A correction reason of at least "
                "3 characters is required"
            ),
        )

    try:
        spare_part = get_active_spare_part(
            db,
            return_data.spare_part_id,
            lock_for_update=True,
        )

        job_card = get_job_card(
            db,
            return_data.job_card_id,
            lock_for_update=True,
        )

        allowed_statuses = {
            "DIAGNOSIS",
            "REPAIR_IN_PROGRESS",
        }

        if job_card.status not in allowed_statuses:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Spare parts can only be removed "
                    "during Diagnosis or "
                    "Repair In Progress"
                ),
            )

        transactions = (
            db.query(StockTransaction)
            .filter(
                StockTransaction.spare_part_id
                == return_data.spare_part_id,
                StockTransaction.job_card_id
                == return_data.job_card_id,
                StockTransaction.transaction_type.in_(
                    ["ISSUE", "RETURN"]
                ),
            )
            .order_by(
                StockTransaction.id.asc()
            )
            .all()
        )

        issue_transactions = [
            transaction
            for transaction in transactions
            if transaction.transaction_type
            == "ISSUE"
        ]

        return_transactions = [
            transaction
            for transaction in transactions
            if transaction.transaction_type
            == "RETURN"
        ]

        total_issued = sum(
            transaction.quantity
            for transaction in issue_transactions
        )

        total_returned = sum(
            transaction.quantity
            for transaction in return_transactions
        )

        returnable_quantity = (
            total_issued - total_returned
        )

        if returnable_quantity <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "No issued quantity is available "
                    "to remove for this spare part"
                ),
            )

        if return_data.quantity > returnable_quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Return quantity cannot exceed "
                    f"the available issued quantity "
                    f"of {returnable_quantity}"
                ),
            )

        latest_issue = next(
            (
                transaction
                for transaction in reversed(
                    issue_transactions
                )
            ),
            None,
        )

        unit_price = (
            latest_issue.unit_price
            if latest_issue is not None
            else spare_part.selling_price
        )

        line_total = (
            unit_price * return_data.quantity
        )

        spare_part.current_stock += (
            return_data.quantity
        )

        transaction = StockTransaction(
            spare_part_id=return_data.spare_part_id,
            job_card_id=return_data.job_card_id,
            transaction_type="RETURN",
            quantity=return_data.quantity,
            unit_price=unit_price,
            line_total=line_total,
            reference=job_card.job_code,
            remarks=correction_reason,
        )

        db.add(transaction)

        if commit:
            db.commit()
            db.refresh(transaction)
        else:
            db.flush()

        return transaction

    except Exception:
        db.rollback()
        raise
def adjust_stock(
    db: Session,
    adjustment_data: StockAdjustmentCreate,
):
    spare_part = get_active_spare_part(
        db,
        adjustment_data.spare_part_id,
    )

    old_quantity = spare_part.current_stock
    new_quantity = adjustment_data.new_quantity
    difference = new_quantity - old_quantity

    spare_part.current_stock = new_quantity

    transaction = StockTransaction(
        spare_part_id=adjustment_data.spare_part_id,
        job_card_id=None,
        transaction_type="ADJUSTMENT",
        quantity=difference,
        unit_price=spare_part.purchase_price,
        line_total=0,
        reference=None,
        remarks=adjustment_data.remarks,
    )

    db.add(transaction)

    try:
        db.commit()
        db.refresh(transaction)

    except Exception:
        db.rollback()
        raise

    return transaction


def get_stock_transactions(
    db: Session,
):
    return (
        db.query(StockTransaction)
        .order_by(StockTransaction.id.desc())
        .all()
    )


def get_part_transactions(
    db: Session,
    spare_part_id: int,
):
    get_active_spare_part(
        db,
        spare_part_id,
    )

    return (
        db.query(StockTransaction)
        .filter(
            StockTransaction.spare_part_id
            == spare_part_id
        )
        .order_by(StockTransaction.id.desc())
        .all()
    )


def get_job_card_transactions(
    db: Session,
    job_card_id: int,
):
    get_job_card(
        db,
        job_card_id,
    )

    return (
        db.query(StockTransaction)
        .filter(
            StockTransaction.job_card_id
            == job_card_id
        )
        .order_by(StockTransaction.id.desc())
        .all()
    )
