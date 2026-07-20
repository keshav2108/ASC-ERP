from fastapi import HTTPException, status
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.jwt import create_access_token
from app.auth.password import (
    hash_password,
    verify_password,
)
from app.models.user import User
from app.schemas.user import UserCreate


def generate_unique_employee_id(
    db: Session,
) -> str:
    existing_employee_ids = (
        db.query(User.employee_id)
        .filter(
            User.employee_id.like("EMP%")
        )
        .all()
    )

    used_sequence_numbers: list[int] = []

    for employee_id_row in existing_employee_ids:
        employee_id = employee_id_row[0]

        if not employee_id:
            continue

        normalized_employee_id = (
            employee_id.strip().upper()
        )

        sequence_part = (
            normalized_employee_id[3:]
        )

        if sequence_part.isdigit():
            used_sequence_numbers.append(
                int(sequence_part)
            )

    sequence_number = (
        max(
            used_sequence_numbers,
            default=0,
        )
        + 1
    )

    while True:
        employee_id = (
            f"EMP{sequence_number:03d}"
        )

        existing_employee = (
            db.query(User.id)
            .filter(
                User.employee_id == employee_id
            )
            .first()
        )

        if existing_employee is None:
            return employee_id

        sequence_number += 1


def validate_unique_user_fields(
    db: Session,
    user_data: UserCreate,
) -> None:
    existing_mobile = (
        db.query(User.id)
        .filter(
            User.mobile == user_data.mobile
        )
        .first()
    )

    if existing_mobile:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "A user with this mobile number "
                "already exists"
            ),
        )

    if user_data.email is not None:
        existing_email = (
            db.query(User.id)
            .filter(
                User.email == user_data.email
            )
            .first()
        )

        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "A user with this email "
                    "already exists"
                ),
            )


def create_user(
    db: Session,
    user_data: UserCreate,
) -> User:
    validate_unique_user_fields(
        db,
        user_data,
    )

    new_user = User(
        employee_id=generate_unique_employee_id(
            db
        ),
        full_name=user_data.full_name,
        email=user_data.email,
        mobile=user_data.mobile,
        password_hash=hash_password(
            user_data.password
        ),
        role=user_data.role,
        status="ACTIVE",
    )

    db.add(new_user)

    try:
        db.commit()
        db.refresh(new_user)

    except IntegrityError as error:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "A user with the same employee ID, "
                "mobile number, email, or username "
                "already exists"
            ),
        ) from error

    except Exception:
        db.rollback()
        raise

    return new_user


def login_user(
    db: Session,
    login_id: str,
    password: str,
):
    normalized_login_id = login_id.strip()

    user = (
        db.query(User)
        .filter(
            or_(
                User.username
                == normalized_login_id,
                User.mobile
                == normalized_login_id,
            )
        )
        .first()
    )

    invalid_credentials = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=(
            "Invalid username, mobile number, "
            "or password"
        ),
        headers={
            "WWW-Authenticate": "Bearer",
        },
    )

    if user is None:
        raise invalid_credentials

    if not verify_password(
        password,
        user.password_hash,
    ):
        raise invalid_credentials

    normalized_status = (
        user.status or ""
    ).strip().upper()

    if normalized_status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Your account is inactive. "
                "Contact the administrator."
            ),
        )

    access_token = create_access_token(
        data={
            "sub": str(user.id),
        }
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
    }
