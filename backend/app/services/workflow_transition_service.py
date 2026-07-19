from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.workflow_transition import WorkflowTransition
from app.schemas.workflow_transition import (
    WorkflowTransitionCreate,
    WorkflowTransitionUpdate,
)


def normalize_status(
    value: str,
) -> str:
    return value.strip().upper().replace(" ", "_")


def get_workflow_transition_by_id(
    db: Session,
    transition_id: int,
):
    transition = (
        db.query(WorkflowTransition)
        .filter(
            WorkflowTransition.id == transition_id
        )
        .first()
    )

    if not transition:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Workflow transition not found",
        )

    return transition


def create_workflow_transition(
    db: Session,
    transition_data: WorkflowTransitionCreate,
):
    from_status = normalize_status(
        transition_data.from_status
    )

    to_status = normalize_status(
        transition_data.to_status
    )

    if from_status == to_status:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "From status and to status "
                "cannot be the same"
            ),
        )

    existing_transition = (
        db.query(WorkflowTransition)
        .filter(
            WorkflowTransition.from_status == from_status,
            WorkflowTransition.to_status == to_status,
        )
        .first()
    )

    if existing_transition:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Workflow transition already exists",
        )

    transition = WorkflowTransition(
        from_status=from_status,
        to_status=to_status,
        action=transition_data.action.strip(),
    )

    db.add(transition)

    try:
        db.commit()
        db.refresh(transition)

    except Exception:
        db.rollback()
        raise

    return transition


def get_workflow_transitions(
    db: Session,
    include_inactive: bool = False,
):
    query = db.query(WorkflowTransition)

    if not include_inactive:
        query = query.filter(
            WorkflowTransition.is_active.is_(True)
        )

    return (
        query
        .order_by(
            WorkflowTransition.from_status.asc(),
            WorkflowTransition.to_status.asc(),
        )
        .all()
    )


def get_allowed_transitions(
    db: Session,
    current_status: str,
):
    normalized_status = normalize_status(
        current_status
    )

    return (
        db.query(WorkflowTransition)
        .filter(
            WorkflowTransition.from_status
            == normalized_status,
            WorkflowTransition.is_active.is_(True),
        )
        .order_by(
            WorkflowTransition.id.asc()
        )
        .all()
    )


def validate_workflow_transition(
    db: Session,
    from_status: str,
    to_status: str,
):
    normalized_from = normalize_status(
        from_status
    )

    normalized_to = normalize_status(
        to_status
    )

    transition = (
        db.query(WorkflowTransition)
        .filter(
            WorkflowTransition.from_status
            == normalized_from,
            WorkflowTransition.to_status
            == normalized_to,
            WorkflowTransition.is_active.is_(True),
        )
        .first()
    )

    if not transition:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Invalid workflow transition: "
                f"{normalized_from} to {normalized_to}"
            ),
        )

    return transition


def update_workflow_transition(
    db: Session,
    transition_id: int,
    transition_data: WorkflowTransitionUpdate,
):
    transition = get_workflow_transition_by_id(
        db,
        transition_id,
    )

    update_data = transition_data.model_dump(
        exclude_unset=True
    )

    if (
        "action" in update_data
        and update_data["action"] is not None
    ):
        update_data["action"] = (
            update_data["action"].strip()
        )

    for field, value in update_data.items():
        setattr(
            transition,
            field,
            value,
        )

    try:
        db.commit()
        db.refresh(transition)

    except Exception:
        db.rollback()
        raise

    return transition


def deactivate_workflow_transition(
    db: Session,
    transition_id: int,
):
    transition = get_workflow_transition_by_id(
        db,
        transition_id,
    )

    transition.is_active = False

    db.commit()
    db.refresh(transition)

    return {
        "message": (
            "Workflow transition deactivated successfully"
        ),
        "from_status": transition.from_status,
        "to_status": transition.to_status,
    }
