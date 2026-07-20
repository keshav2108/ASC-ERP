from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.permissions import (
    get_active_user,
    require_roles,
)
from app.database import get_db
from app.models.user import User
from app.schemas.login import LoginRequest
from app.schemas.user import UserCreate, UserResponse
from app.services.auth_service import (
    create_user,
    login_user,
)


admin_only = require_roles(
    "ADMIN",
)


router = APIRouter(
    prefix="/api/v1/auth",
    tags=["Authentication"],
)


@router.post(
    "/register",
    response_model=UserResponse,
    dependencies=[
        Depends(admin_only),
    ],
)
def register_user(
    user: UserCreate,
    db: Session = Depends(get_db),
):
    return create_user(
        db,
        user,
    )


@router.post("/login")
def login(
    user: LoginRequest,
    db: Session = Depends(get_db),
):
    return login_user(
        db=db,
        login_id=user.username,
        password=user.password,
    )


@router.get("/me")
def get_profile(
    current_user: User = Depends(
        get_active_user
    ),
):
    return {
        "employee_id": current_user.employee_id,
        "full_name": current_user.full_name,
        "username": current_user.username,
        "mobile": current_user.mobile,
        "email": current_user.email,
        "role": current_user.role,
        "status": current_user.status,
    }
