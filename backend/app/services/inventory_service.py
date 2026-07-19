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
):
    spare_part = (
        db.query(SparePart)
        .filter(
            SparePart.id == spare_part_id,
            SparePart.is_active.is_(True),
        )
        .first()
    )

    if not spare_part:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active spare part not found",
        )

    return spare_part


def get_job_card(
    db: Session,
    job_card_id: int,
):
    job_card = (
        db.query(JobCard)
        .filter(JobCard.id == job_card_id)
        .first()
    )

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

    transaction = StockTransaction(
        spare_part_id=stock_data.spare_part_id,
        job_card_id=None,
        transaction_type="STOCK_IN",
        quantity=stock_data.quantity,
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
):
    spare_part = get_active_spare_part(
        db,
        issue_data.spare_part_id,
    )

    job_card = get_job_card(
        db,
        issue_data.job_card_id,
    )

    if job_card.status in {
        "COMPLETED",
        "READY_FOR_DELIVERY",
        "CANCELLED",
    }:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Parts cannot be issued to "
                "this job card"
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

    transaction = StockTransaction(
        spare_part_id=issue_data.spare_part_id,
        job_card_id=issue_data.job_card_id,
        transaction_type="ISSUE",
        quantity=issue_data.quantity,
        reference=job_card.job_code,
        remarks=issue_data.remarks,
    )

    db.add(transaction)

    try:
        db.commit()
        db.refresh(transaction)

    except Exception:
        db.rollback()
        raise

    return transaction


def return_stock_from_job_card(
    db: Session,
    return_data: StockReturnCreate,
):
    spare_part = get_active_spare_part(
        db,
        return_data.spare_part_id,
    )

    job_card = get_job_card(
        db,
        return_data.job_card_id,
    )

    total_issued = sum(
        transaction.quantity
        for transaction in (
            db.query(StockTransaction)
            .filter(
                StockTransaction.spare_part_id
                == return_data.spare_part_id,
                StockTransaction.job_card_id
                == return_data.job_card_id,
                StockTransaction.transaction_type
                == "ISSUE",
            )
            .all()
        )
    )

    total_returned = sum(
        transaction.quantity
        for transaction in (
            db.query(StockTransaction)
            .filter(
                StockTransaction.spare_part_id
                == return_data.spare_part_id,
                StockTransaction.job_card_id
                == return_data.job_card_id,
                StockTransaction.transaction_type
                == "RETURN",
            )
            .all()
        )
    )

    returnable_quantity = (
        total_issued - total_returned
    )

    if return_data.quantity > returnable_quantity:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Maximum returnable quantity is "
                f"{returnable_quantity}"
            ),
        )

    spare_part.current_stock += return_data.quantity

    transaction = StockTransaction(
        spare_part_id=return_data.spare_part_id,
        job_card_id=return_data.job_card_id,
        transaction_type="RETURN",
        quantity=return_data.quantity,
        reference=job_card.job_code,
        remarks=return_data.remarks,
    )

    db.add(transaction)

    try:
        db.commit()
        db.refresh(transaction)

    except Exception:
        db.rollback()
        raise

    return transaction


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

    spare_part.current_stock = new_quantity

    transaction = StockTransaction(
        spare_part_id=adjustment_data.spare_part_id,
        job_card_id=None,
        transaction_type="ADJUSTMENT",
        quantity=new_quantity - old_quantity,
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
