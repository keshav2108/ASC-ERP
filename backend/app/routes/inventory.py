from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)
from sqlalchemy.orm import Session

from app.auth.permissions import (
    normalize_role,
    require_roles,
)
from app.database import get_db
from app.models.job_card import JobCard
from app.models.technician import Technician
from app.models.user import User
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


inventory_view_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "ACCOUNTANT",
)

inventory_job_card_view_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "ACCOUNTANT",
    "TECHNICIAN",
)

inventory_manage_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
)


router = APIRouter(
    prefix="/api/v1/inventory",
    tags=["Inventory"],
)


def validate_job_card_transaction_access(
    db: Session,
    current_user: User,
    job_card_id: int,
) -> None:
    if normalize_role(current_user.role) != "TECHNICIAN":
        return

    technician = (
        db.query(Technician)
        .filter(
            Technician.user_id == current_user.id,
            Technician.status == "ACTIVE",
        )
        .first()
    )

    if technician is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Your account is not linked to "
                "an active technician profile"
            ),
        )

    job_card = (
        db.query(JobCard)
        .filter(JobCard.id == job_card_id)
        .first()
    )

    if job_card is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Job Card not found",
        )

    if job_card.technician_id != technician.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "You can only view spare parts for "
                "Job Cards assigned to you"
            ),
        )


@router.post(
    "/stock-in",
    response_model=StockTransactionResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(inventory_manage_access),
    ],
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
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(inventory_manage_access),
    ],
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
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(inventory_manage_access),
    ],
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
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(inventory_manage_access),
    ],
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
    dependencies=[
        Depends(inventory_view_access),
    ],
)
def list_stock_transactions(
    db: Session = Depends(get_db),
):
    return get_stock_transactions(db)


@router.get(
    "/transactions/part/{spare_part_id}",
    response_model=list[StockTransactionResponse],
    dependencies=[
        Depends(inventory_view_access),
    ],
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
    current_user: User = Depends(
        inventory_job_card_view_access
    ),
):
    validate_job_card_transaction_access(
        db,
        current_user,
        job_card_id,
    )

    return get_job_card_transactions(
        db,
        job_card_id,
    )
