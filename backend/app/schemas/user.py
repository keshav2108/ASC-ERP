from pydantic import (
    BaseModel,
    EmailStr,
    Field,
    field_validator,
)


ALLOWED_USER_ROLES = {
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
    "TECHNICIAN",
    "ACCOUNTANT",
}


def normalize_role_value(
    value: object,
) -> str:
    if not isinstance(value, str):
        raise ValueError(
            "Role must be a text value"
        )

    normalized_role = (
        value.strip()
        .upper()
        .replace("-", "_")
        .replace(" ", "_")
    )

    if normalized_role not in ALLOWED_USER_ROLES:
        allowed_roles = ", ".join(
            sorted(ALLOWED_USER_ROLES)
        )

        raise ValueError(
            "Invalid role. "
            f"Allowed roles: {allowed_roles}"
        )

    return normalized_role


class UserCreate(BaseModel):
    full_name: str = Field(
        min_length=2,
        max_length=100,
    )

    mobile: str = Field(
        min_length=10,
        max_length=10,
        pattern=r"^\d{10}$",
    )

    password: str = Field(
        min_length=8,
        max_length=128,
    )

    email: EmailStr | None = None

    role: str

    @field_validator(
        "full_name",
        mode="before",
    )
    @classmethod
    def clean_full_name(
        cls,
        value: object,
    ) -> object:
        if isinstance(value, str):
            return " ".join(
                value.strip().split()
            )

        return value

    @field_validator(
        "mobile",
        mode="before",
    )
    @classmethod
    def clean_mobile(
        cls,
        value: object,
    ) -> object:
        if isinstance(value, str):
            return value.strip()

        return value

    @field_validator(
        "email",
        mode="before",
    )
    @classmethod
    def clean_email(
        cls,
        value: object,
    ) -> object:
        if isinstance(value, str):
            cleaned_value = value.strip().lower()

            if not cleaned_value:
                return None

            return cleaned_value

        return value

    @field_validator(
        "role",
        mode="before",
    )
    @classmethod
    def validate_role(
        cls,
        value: object,
    ) -> str:
        return normalize_role_value(value)


class UserResponse(BaseModel):
    employee_id: str
    full_name: str
    mobile: str
    email: str | None
    role: str
    status: str

    model_config = {
        "from_attributes": True,
    }
