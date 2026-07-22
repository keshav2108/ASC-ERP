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
from app.schemas.job_card import (
    JobCardResponse,
    JobCardUpdate,
)
from app.schemas.stock_transaction import (
    StockIssueCreate,
    StockTransactionResponse,
)
from app.services.job_card_service import (
    get_job_card_by_id,
    get_job_cards,
    get_technician_job_cards,
    update_job_card,
)
from app.services.inventory_service import (
    get_job_card_transactions,
    issue_stock_to_job_card,
)
from app.services.job_card_workflow_service import (
    change_job_card_status,
)


job_card_view_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
    "TECHNICIAN",
    "ACCOUNTANT",
)

job_card_manager_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
)

job_card_technical_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "TECHNICIAN",
)


router = APIRouter(
    prefix="/api/v1/job-cards",
    tags=["Job Cards"],
)


def get_user_technician(
    db: Session,
    current_user: User,
) -> Technician:
    technician = (
        db.query(Technician)
        .filter(
            Technician.user_id
            == current_user.id,
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

    return technician


def validate_job_card_access(
    db: Session,
    current_user: User,
    job_card: JobCard,
) -> None:
    current_role = normalize_role(
        current_user.role
    )

    if current_role != "TECHNICIAN":
        return

    technician = get_user_technician(
        db,
        current_user,
    )

    if job_card.technician_id != technician.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "You can access only Job Cards "
                "assigned to you"
            ),
        )


@router.get(
    "/",
    response_model=list[JobCardResponse],
)
def list_job_cards(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_view_access
    ),
):
    current_role = normalize_role(
        current_user.role
    )

    if current_role == "TECHNICIAN":
        technician = get_user_technician(
            db,
            current_user,
        )

        return get_technician_job_cards(
            db,
            technician.id,
        )

    return get_job_cards(db)


@router.get(
    "/technician/{technician_id}",
    response_model=list[JobCardResponse],
)
def list_technician_job_cards(
    technician_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_view_access
    ),
):
    current_role = normalize_role(
        current_user.role
    )

    if current_role == "TECHNICIAN":
        technician = get_user_technician(
            db,
            current_user,
        )

        if technician.id != technician_id:
            raise HTTPException(
                status_code=(
                    status.HTTP_403_FORBIDDEN
                ),
                detail=(
                    "You can view only your "
                    "assigned Job Cards"
                ),
            )

    return get_technician_job_cards(
        db,
        technician_id,
    )


@router.get(
    "/{job_card_id}",
    response_model=JobCardResponse,
)
def get_job_card(
    job_card_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_view_access
    ),
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    validate_job_card_access(
        db,
        current_user,
        job_card,
    )

    return job_card


@router.patch(
    "/{job_card_id}",
    response_model=JobCardResponse,
    dependencies=[
        Depends(job_card_manager_access),
    ],
)
def edit_job_card(
    job_card_id: int,
    job_data: JobCardUpdate,
    db: Session = Depends(get_db),
):
    return update_job_card(
        db,
        job_card_id,
        job_data,
    )


@router.post(
    "/{job_card_id}/accept",
    response_model=JobCardResponse,
)
def accept_job(
    job_card_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_technical_access
    ),
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    validate_job_card_access(
        db,
        current_user,
        job_card,
    )

    return change_job_card_status(
        db,
        job_card_id,
        "ACCEPTED",
    )


@router.post(
    "/{job_card_id}/start-diagnosis",
    response_model=JobCardResponse,
)
def start_diagnosis(
    job_card_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_technical_access
    ),
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    validate_job_card_access(
        db,
        current_user,
        job_card,
    )

    return change_job_card_status(
        db,
        job_card_id,
        "DIAGNOSIS",
    )


@router.post(
    "/{job_card_id}/waiting-for-parts",
    response_model=JobCardResponse,
)
def waiting_for_parts(
    job_card_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_technical_access
    ),
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    validate_job_card_access(
        db,
        current_user,
        job_card,
    )

    return change_job_card_status(
        db,
        job_card_id,
        "WAITING_PARTS",
    )


@router.post(
    "/{job_card_id}/start-repair",
    response_model=JobCardResponse,
)
def start_repair(
    job_card_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_technical_access
    ),
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    validate_job_card_access(
        db,
        current_user,
        job_card,
    )

    return change_job_card_status(
        db,
        job_card_id,
        "REPAIR_IN_PROGRESS",
    )


@router.post(
    "/{job_card_id}/start-testing",
    response_model=JobCardResponse,
)
def start_testing(
    job_card_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_technical_access
    ),
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    validate_job_card_access(
        db,
        current_user,
        job_card,
    )

    return change_job_card_status(
        db,
        job_card_id,
        "TESTING",
    )


@router.post(
    "/{job_card_id}/complete",
    response_model=JobCardResponse,
)
def complete_job(
    job_card_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_technical_access
    ),
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    validate_job_card_access(
        db,
        current_user,
        job_card,
    )

    return change_job_card_status(
        db,
        job_card_id,
        "COMPLETED",
    )


@router.get(
    "/{job_card_id}/spare-parts",
    response_model=list[StockTransactionResponse],
)
def list_job_card_spare_parts(
    job_card_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_view_access
    ),
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    validate_job_card_access(
        db,
        current_user,
        job_card,
    )

    return get_job_card_transactions(
        db,
        job_card_id,
    )


@router.post(
    "/{job_card_id}/spare-parts",
    response_model=StockTransactionResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_spare_part_to_job_card(
    job_card_id: int,
    issue_data: StockIssueCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        job_card_technical_access
    ),
):
    job_card = get_job_card_by_id(
        db,
        job_card_id,
    )

    validate_job_card_access(
        db,
        current_user,
        job_card,
    )

    if issue_data.job_card_id != job_card_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Job Card ID in the request does not "
                "match the Job Card in the URL"
            ),
        )

    if job_card.status not in {
        "DIAGNOSIS",
        "REPAIR_IN_PROGRESS",
    }:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Spare parts can only be added during "
                "diagnosis or repair"
            ),
        )

    transaction = issue_stock_to_job_card(
        db,
        issue_data,
    )

    # Phase 4: Auto-transition to REPAIR_IN_PROGRESS if currently in DIAGNOSIS
    if job_card.status == "DIAGNOSIS":
        change_job_card_status(
            db,
            job_card_id,
            "REPAIR_IN_PROGRESS",
        )

    return transaction


@router.post(
    "/{job_card_id}/ready-for-delivery",
    response_model=JobCardResponse,
    dependencies=[
        Depends(job_card_manager_access),
    ],
)
def ready_for_delivery(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "READY_FOR_DELIVERY",
    )


@router.post(
    "/{job_card_id}/cancel",
    response_model=JobCardResponse,
    dependencies=[
        Depends(job_card_manager_access),
    ],
)
def cancel_job(
    job_card_id: int,
    db: Session = Depends(get_db),
):
    return change_job_card_status(
        db,
        job_card_id,
        "CANCELLED",
    )
