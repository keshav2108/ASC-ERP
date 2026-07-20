from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.permissions import require_roles
from app.database import get_db
from app.schemas.dashboard import (
    DashboardOverviewResponse,
)
from app.services.dashboard_service import (
    get_dashboard_overview,
)


dashboard_access = require_roles(
    "ADMIN",
    "SERVICE_MANAGER",
    "ACCOUNTANT",
)


router = APIRouter(
    prefix="/api/v1/dashboard",
    tags=["Dashboard"],
    dependencies=[
        Depends(dashboard_access),
    ],
)


@router.get(
    "/overview",
    response_model=DashboardOverviewResponse,
)
def dashboard_overview(
    db: Session = Depends(get_db),
):
    return get_dashboard_overview(db)
