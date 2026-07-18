from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.master_option import MasterOption


def normalize_master_code(
    value: str,
) -> str:
    return value.strip().upper().replace(" ", "_")


def validate_master_option(
    db: Session,
    option_type: str,
    code: str,
) -> str:
    normalized_type = normalize_master_code(
        option_type
    )

    normalized_code = normalize_master_code(
        code
    )

    option = (
        db.query(MasterOption)
        .filter(
            MasterOption.option_type == normalized_type,
            MasterOption.code == normalized_code,
            MasterOption.is_active.is_(True),
        )
        .first()
    )

    if not option:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Invalid {normalized_type}: "
                f"{normalized_code}"
            ),
        )

    return normalized_code
