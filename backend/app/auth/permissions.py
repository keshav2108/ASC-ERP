from collections.abc import Callable

from fastapi import Depends, HTTPException, status

from app.auth.dependencies import get_current_user
from app.models.user import User


def normalize_role(role: str | None) -> str:
    if role is None:
        return ""

    return (
        role.strip()
        .upper()
        .replace("-", "_")
        .replace(" ", "_")
    )


def normalize_user_status(
    user_status: str | None,
) -> str:
    if user_status is None:
        return ""

    return user_status.strip().upper()


def get_active_user(
    current_user: User = Depends(
        get_current_user
    ),
) -> User:
    if (
        normalize_user_status(
            current_user.status
        )
        != "ACTIVE"
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Your account is inactive. "
                "Contact the administrator."
            ),
        )

    return current_user


def require_roles(
    *allowed_roles: str,
) -> Callable[..., User]:
    normalized_allowed_roles = {
        normalize_role(role)
        for role in allowed_roles
        if normalize_role(role)
    }

    if not normalized_allowed_roles:
        raise ValueError(
            "At least one allowed role is required"
        )

    def role_checker(
        current_user: User = Depends(
            get_active_user
        ),
    ) -> User:
        current_role = normalize_role(
            current_user.role
        )

        if current_role not in (
            normalized_allowed_roles
        ):
            allowed_roles_text = ", ".join(
                sorted(
                    normalized_allowed_roles
                )
            )

            raise HTTPException(
                status_code=(
                    status.HTTP_403_FORBIDDEN
                ),
                detail=(
                    "You do not have permission "
                    "to perform this action. "
                    f"Allowed roles: "
                    f"{allowed_roles_text}"
                ),
            )

        return current_user

    return role_checker
