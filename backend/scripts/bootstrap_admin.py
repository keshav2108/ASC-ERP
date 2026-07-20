from getpass import getpass
from pathlib import Path
import sys

from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import func


PROJECT_ROOT = Path(__file__).resolve().parents[1]

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(
        0,
        str(PROJECT_ROOT),
    )


from app.database import SessionLocal
from app.models.user import User
from app.schemas.user import UserCreate
from app.services.auth_service import create_user


def prompt_required(
    label: str,
) -> str:
    while True:
        value = input(label).strip()

        if value:
            return value

        print("This field is required.")


def prompt_email() -> str | None:
    value = input(
        "Email address (optional): "
    ).strip()

    return value or None


def prompt_password() -> str:
    while True:
        password = getpass(
            "Password: "
        )

        confirmation = getpass(
            "Confirm password: "
        )

        if password != confirmation:
            print(
                "Passwords do not match. "
                "Please try again."
            )
            continue

        return password


def admin_already_exists(
    db,
) -> bool:
    existing_admin = (
        db.query(User.id)
        .filter(
            func.upper(
                func.trim(User.role)
            )
            == "ADMIN"
        )
        .first()
    )

    return existing_admin is not None


def main() -> int:
    print()
    print("ASC Manager - First Admin Setup")
    print("--------------------------------")

    db = SessionLocal()

    try:
        if admin_already_exists(db):
            print(
                "Bootstrap cancelled: an Admin "
                "account already exists."
            )
            return 1

        full_name = prompt_required(
            "Full name: "
        )

        mobile = prompt_required(
            "Mobile number: "
        )

        email = prompt_email()

        password = prompt_password()

        try:
            admin_data = UserCreate(
                full_name=full_name,
                mobile=mobile,
                email=email,
                password=password,
                role="ADMIN",
            )

        except ValidationError as error:
            print()
            print("Validation failed:")

            for issue in error.errors():
                field = ".".join(
                    str(item)
                    for item in issue["loc"]
                )

                print(
                    f"- {field}: "
                    f"{issue['msg']}"
                )

            return 1

        try:
            admin = create_user(
                db,
                admin_data,
            )

        except HTTPException as error:
            print()
            print(
                "Admin creation failed: "
                f"{error.detail}"
            )

            return 1

        print()
        print(
            "Admin account created successfully."
        )
        print(
            f"Employee ID: {admin.employee_id}"
        )
        print(
            f"Full name: {admin.full_name}"
        )
        print(
            f"Mobile: {admin.mobile}"
        )
        print(
            f"Role: {admin.role}"
        )
        print(
            f"Status: {admin.status}"
        )
        print()
        print(
            "Use the mobile number and password "
            "to log in."
        )

        return 0

    except KeyboardInterrupt:
        print()
        print("Admin setup cancelled.")

        return 1

    except Exception as error:
        db.rollback()

        print()
        print(
            "Unexpected error while creating "
            f"Admin: {error}"
        )

        return 1

    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
