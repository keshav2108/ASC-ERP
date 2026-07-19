from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.spare_part import SparePart
from app.schemas.spare_part import (
    SparePartCreate,
    SparePartUpdate,
)
from app.utils.spare_part_code_generator import (
    generate_spare_part_code,
)


def get_spare_part_by_id(
    db: Session,
    spare_part_id: int,
):
    spare_part = (
        db.query(SparePart)
        .filter(SparePart.id == spare_part_id)
        .first()
    )

    if not spare_part:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Spare part not found",
        )

    return spare_part


def create_spare_part(
    db: Session,
    part_data: SparePartCreate,
):
    existing_part = (
        db.query(SparePart)
        .filter(
            func.lower(SparePart.part_name)
            == part_data.part_name.strip().lower(),
            SparePart.brand == part_data.brand,
        )
        .first()
    )

    if existing_part:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Spare part already exists",
        )

    last_id = (
        db.query(func.max(SparePart.id))
        .scalar()
        or 0
    )

    spare_part = SparePart(
        part_code=generate_spare_part_code(
            last_id + 1
        ),
        part_name=part_data.part_name.strip(),
        brand=(
            part_data.brand.strip()
            if part_data.brand
            else None
        ),
        product_category=(
            part_data.product_category.strip()
            if part_data.product_category
            else None
        ),
        unit=part_data.unit.strip().upper(),
        purchase_price=part_data.purchase_price,
        selling_price=part_data.selling_price,
        current_stock=part_data.current_stock,
        minimum_stock=part_data.minimum_stock,
    )

    db.add(spare_part)

    try:
        db.commit()
        db.refresh(spare_part)

    except Exception:
        db.rollback()
        raise

    return spare_part


def get_spare_parts(
    db: Session,
    include_inactive: bool = False,
):
    query = db.query(SparePart)

    if not include_inactive:
        query = query.filter(
            SparePart.is_active.is_(True)
        )

    return (
        query
        .order_by(SparePart.part_name.asc())
        .all()
    )


def get_low_stock_parts(
    db: Session,
):
    return (
        db.query(SparePart)
        .filter(
            SparePart.is_active.is_(True),
            SparePart.current_stock
            <= SparePart.minimum_stock,
        )
        .order_by(SparePart.current_stock.asc())
        .all()
    )


def update_spare_part(
    db: Session,
    spare_part_id: int,
    part_data: SparePartUpdate,
):
    spare_part = get_spare_part_by_id(
        db,
        spare_part_id,
    )

    update_data = part_data.model_dump(
        exclude_unset=True
    )

    if (
        "part_name" in update_data
        and update_data["part_name"] is not None
    ):
        update_data["part_name"] = (
            update_data["part_name"].strip()
        )

    if (
        "brand" in update_data
        and update_data["brand"] is not None
    ):
        update_data["brand"] = (
            update_data["brand"].strip()
        )

    if (
        "product_category" in update_data
        and update_data["product_category"] is not None
    ):
        update_data["product_category"] = (
            update_data["product_category"].strip()
        )

    if (
        "unit" in update_data
        and update_data["unit"] is not None
    ):
        update_data["unit"] = (
            update_data["unit"].strip().upper()
        )

    for field, value in update_data.items():
        setattr(
            spare_part,
            field,
            value,
        )

    try:
        db.commit()
        db.refresh(spare_part)

    except Exception:
        db.rollback()
        raise

    return spare_part


def deactivate_spare_part(
    db: Session,
    spare_part_id: int,
):
    spare_part = get_spare_part_by_id(
        db,
        spare_part_id,
    )

    spare_part.is_active = False

    db.commit()
    db.refresh(spare_part)

    return {
        "message": "Spare part deactivated successfully",
        "part_code": spare_part.part_code,
    }
