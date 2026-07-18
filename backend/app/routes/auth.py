from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.user import UserCreate, UserResponse
from app.schemas.login import LoginRequest
from app.services.auth_service import create_user, login_user
from app.auth.dependencies import get_current_user
from app.models.user import User

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["Authentication"]
)


@router.post(
    "/register",
    response_model=UserResponse
)
def register_user(
    user: UserCreate,
    db: Session = Depends(get_db)
):

    return create_user(
        db,
        user
    )
@router.post(
    "/login"
)
def login(
    user: LoginRequest,
    db: Session = Depends(get_db)
):

    return login_user(
        db,
        user.mobile,
        user.password
    )

@router.get("/me")
def get_profile(
    current_user: User = Depends(get_current_user)
):

    return {
        "employee_id": current_user.employee_id,
        "full_name": current_user.full_name,
        "mobile": current_user.mobile,
        "email": current_user.email,
        "role": current_user.role,
        "status": current_user.status
    }
