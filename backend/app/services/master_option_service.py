from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.master_option import MasterOption
from app.schemas.master_option import (
    MasterOptionCreate,
    MasterOptionUpdate,
)


def normalize_value(value: str) -> str:
    return value.strip().upper().replace(" ", "_")


def create_master_option(
    db: Session,
    option_data: MasterOptionCreate,
):
    option_type = normalize_value(
        option_data.option_type
    )

    code = normalize_value(
        option_data.code
    )

    existing_option = (
        db.query(MasterOption)
        .filter(
            MasterOption.option_type == option_type,
            MasterOption.code == code,
        )
        .first()
    )

    if existing_option:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Master option already exists",
        )

    new_option = MasterOption(
        option_type=option_type,
        code=code,
        label=option_data.label.strip(),
        display_order=option_data.display_order,
    )

    db.add(new_option)

    try:
        db.commit()
        db.refresh(new_option)
    except Exception:
        db.rollback()
        raise

    return new_option


def get_master_options(
    db: Session,
    option_type: str,
    include_inactive: bool = False,
):
    normalized_type = normalize_value(option_type)

    query = (
        db.query(MasterOption)
        .filter(
            MasterOption.option_type == normalized_type
        )
    )

    if not include_inactive:
        query = query.filter(
            MasterOption.is_active.is_(True)
        )

    return (
        query
        .order_by(
            MasterOption.display_order.asc(),
            MasterOption.label.asc(),
        )
        .all()
    )


def get_master_option_by_id(
    db: Session,
    option_id: int,
):
    option = (
        db.query(MasterOption)
        .filter(MasterOption.id == option_id)
        .first()
    )

    if not option:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Master option not found",
        )

    return option


def update_master_option(
    db: Session,
    option_id: int,
    option_data: MasterOptionUpdate,
):
    option = get_master_option_by_id(
        db,
        option_id,
    )

    update_data = option_data.model_dump(
        exclude_unset=True
    )

    for field, value in update_data.items():
        setattr(option, field, value)

    db.commit()
    db.refresh(option)

    return option


def deactivate_master_option(
    db: Session,
    option_id: int,
):
    option = get_master_option_by_id(
        db,
        option_id,
    )

    option.is_active = False

    db.commit()
    db.refresh(option)

    return {
        "message": "Master option deactivated successfully",
        "code": option.code,
    }
