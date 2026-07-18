from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.technician import Technician
from app.models.user import User
from app.schemas.technician import (
    TechnicianCreate,
    TechnicianUpdate,
)
from app.utils.technician_code_generator import (
    generate_technician_code,
)


def get_technician_by_id(
    db: Session,
    technician_id: int,
):
    technician = (
        db.query(Technician)
        .filter(
            Technician.id == technician_id
        )
        .first()
    )

    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Technician not found",
        )

    return technician


def create_technician(
    db: Session,
    technician_data: TechnicianCreate,
):
    existing_mobile = (
        db.query(Technician)
        .filter(
            Technician.mobile == technician_data.mobile
        )
        .first()
    )

    if existing_mobile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mobile number already exists",
        )

    if technician_data.user_id is not None:

        user = (
            db.query(User)
            .filter(
                User.id == technician_data.user_id
            )
            .first()
        )

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        linked_user = (
            db.query(Technician)
            .filter(
                Technician.user_id == technician_data.user_id
            )
            .first()
        )

        if linked_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User is already assigned as technician",
            )

    technician_count = db.query(Technician).count()

    technician = Technician(
        technician_code=generate_technician_code(
            technician_count + 1
        ),
        user_id=technician_data.user_id,
        full_name=technician_data.full_name,
        mobile=technician_data.mobile,
        specialization=technician_data.specialization,
        experience_years=technician_data.experience_years,
    )

    db.add(technician)

    try:
        db.commit()
        db.refresh(technician)

    except Exception:
        db.rollback()
        raise

    return technician


def get_technicians(
    db: Session,
):
    return (
        db.query(Technician)
        .filter(
            Technician.status == "ACTIVE"
        )
        .order_by(
            Technician.id.desc()
        )
        .all()
    )


def update_technician(
    db: Session,
    technician_id: int,
    technician_data: TechnicianUpdate,
):
    technician = get_technician_by_id(
        db,
        technician_id,
    )

    update_data = technician_data.model_dump(
        exclude_unset=True
    )

    if "mobile" in update_data:

        existing_mobile = (
            db.query(Technician)
            .filter(
                Technician.mobile == update_data["mobile"],
                Technician.id != technician_id,
            )
            .first()
        )

        if existing_mobile:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Mobile number already exists",
            )

    if (
        "user_id" in update_data
        and update_data["user_id"] is not None
    ):

        user = (
            db.query(User)
            .filter(
                User.id == update_data["user_id"]
            )
            .first()
        )

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        linked_user = (
            db.query(Technician)
            .filter(
                Technician.user_id == update_data["user_id"],
                Technician.id != technician_id,
            )
            .first()
        )

        if linked_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User is already assigned as technician",
            )

    for field, value in update_data.items():
        setattr(
            technician,
            field,
            value,
        )

    db.commit()
    db.refresh(technician)

    return technician


def deactivate_technician(
    db: Session,
    technician_id: int,
):
    technician = get_technician_by_id(
        db,
        technician_id,
    )

    technician.status = "INACTIVE"
    technician.availability_status = "UNAVAILABLE"

    db.commit()
    db.refresh(technician)

    return {
        "message": "Technician deactivated successfully",
        "technician_code": technician.technician_code,
    }
