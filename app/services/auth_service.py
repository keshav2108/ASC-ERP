from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.user import User
from app.auth.password import hash_password
from app.utils.id_generator import generate_employee_id


def check_mobile_exists(
    db: Session,
    mobile: str
):

    user = (
        db.query(User)
        .filter(User.mobile == mobile)
        .first()
    )

    if user:
        raise HTTPException(
            status_code=400,
            detail="Mobile number already registered"
        )


def check_email_exists(
    db: Session,
    email: str
):

    if not email:
        return

    user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )


def build_user(
    employee_id: str,
    user_data
):

    return User(

        employee_id=employee_id,

        full_name=user_data.full_name,

        email=user_data.email,

        mobile=user_data.mobile,

        password_hash=hash_password(
            user_data.password
        ),

        role=user_data.role
    )


def save_user(
    db: Session,
    user: User
):

    db.add(user)

    db.commit()

    db.refresh(user)

    return user


def create_user(
    db: Session,
    user_data
):

    check_mobile_exists(
        db,
        user_data.mobile
    )

    check_email_exists(
        db,
        user_data.email
    )

    count = db.query(User).count()

    employee_id = generate_employee_id(
        count + 1
    )

    user = build_user(
        employee_id,
        user_data
    )

    return save_user(
        db,
        user
    )
