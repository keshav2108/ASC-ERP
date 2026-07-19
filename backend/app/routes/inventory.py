from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.stock_transaction import (
    StockAdjustmentCreate,
    StockInCreate,
    StockIssueCreate,
    StockReturnCreate,
    StockTransactionResponse,
)
from app.services.inventory_service import (
    adjust_stock,
    get_job_card_transactions,
    get_part_transactions,
    get_stock_transactions,
    issue_stock_to_job_card,
    return_stock_from_job_card,
    stock_in,
)


router = APIRouter(
    prefix="/api/v1/inventory",
    tags=["Inventory"],
)


@router.post(
    "/stock-in",
    response_model=StockTransactionResponse,
    status_code=201,
)
def add_stock(
    stock_data: StockInCreate,
    db: Session = Depends(get_db),
):
    return stock_in(
        db,
        stock_data,
    )


@router.post(
    "/issue",
    response_model=StockTransactionResponse,
    status_code=201,
)
def issue_stock(
    issue_data: StockIssueCreate,
    db: Session = Depends(get_db),
):
    return issue_stock_to_job_card(
        db,
        issue_data,
    )


@router.post(
    "/return",
    response_model=StockTransactionResponse,
    status_code=201,
)
def return_stock(
    return_data: StockReturnCreate,
    db: Session = Depends(get_db),
):
    return return_stock_from_job_card(
        db,
        return_data,
    )


@router.post(
    "/adjust",
    response_model=StockTransactionResponse,
    status_code=201,
)
def update_stock_quantity(
    adjustment_data: StockAdjustmentCreate,
    db: Session = Depends(get_db),
):
    return adjust_stock(
        db,
        adjustment_data,
    )


@router.get(
    "/transactions",
    response_model=list[StockTransactionResponse],
)
def list_stock_transactions(
    db: Session = Depends(get_db),
):
    return get_stock_transactions(db)


@router.get(
    "/transactions/part/{spare_part_id}",
    response_model=list[StockTransactionResponse],
)
def list_part_transactions(
    spare_part_id: int,
    db: Session = Depends(get_db),
):
    return get_part_transactions(
        db,
        spare_part_id,
    )


@router.get(
    "/transactions/job-card/{job_card_id}",
    response_model=list[StockTransactionResponse],
)
def list_job_card_transactions(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return get_job_card_transactions(
        db,
        job_card_id,
    )
