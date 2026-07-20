from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    status,
)
from sqlalchemy.orm import Session

from app.auth.permissions import (
    normalize_role,
    require_roles,
)
from app.database import get_db
from app.models.user import User
from app.schemas.workflow_transition import (
    WorkflowTransitionCreate,
    WorkflowTransitionResponse,
    WorkflowTransitionUpdate,
)
from app.services.workflow_transition_service import (
    create_workflow_transition,
    deactivate_workflow_transition,
    get_allowed_transitions,
    get_workflow_transition_by_id,
    get_workflow_transitions,
    update_workflow_transition,
)


workflow_view_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
    "TECHNICIAN",
    "ACCOUNTANT",
)

workflow_admin_access = require_roles(
    "ADMIN",
)


router = APIRouter(
    prefix="/api/v1/workflow-transitions",
    tags=["Workflow Transitions"],
)


@router.post(
    "/",
    response_model=WorkflowTransitionResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[
        Depends(workflow_admin_access),
    ],
)
def add_workflow_transition(
    transition_data: WorkflowTransitionCreate,
    db: Session = Depends(get_db),
):
    return create_workflow_transition(
        db,
        transition_data,
    )


@router.get(
    "/",
    response_model=list[WorkflowTransitionResponse],
)
def list_workflow_transitions(
    include_inactive: bool = Query(False),
    db: Session = Depends(get_db),
    current_user: User = Depends(
        workflow_view_access
    ),
):
    if (
        include_inactive
        and normalize_role(current_user.role)
        != "ADMIN"
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Only an Admin can view inactive "
                "workflow transitions"
            ),
        )

    return get_workflow_transitions(
        db,
        include_inactive,
    )


@router.get(
    "/allowed/{current_status}",
    response_model=list[WorkflowTransitionResponse],
)
def list_allowed_transitions(
    current_status: str,
    db: Session = Depends(get_db),
    _current_user: User = Depends(
        workflow_view_access
    ),
):
    return get_allowed_transitions(
        db,
        current_status,
    )


@router.get(
    "/{transition_id}",
    response_model=WorkflowTransitionResponse,
)
def get_workflow_transition(
    transition_id: int,
    db: Session = Depends(get_db),
    _current_user: User = Depends(
        workflow_view_access
    ),
):
    return get_workflow_transition_by_id(
        db,
        transition_id,
    )


@router.patch(
    "/{transition_id}",
    response_model=WorkflowTransitionResponse,
    dependencies=[
        Depends(workflow_admin_access),
    ],
)
def edit_workflow_transition(
    transition_id: int,
    transition_data: WorkflowTransitionUpdate,
    db: Session = Depends(get_db),
):
    return update_workflow_transition(
        db,
        transition_id,
        transition_data,
    )


@router.delete(
    "/{transition_id}",
    dependencies=[
        Depends(workflow_admin_access),
    ],
)
def remove_workflow_transition(
    transition_id: int,
    db: Session = Depends(get_db),
):
    return deactivate_workflow_transition(
        db,
        transition_id,
    )
