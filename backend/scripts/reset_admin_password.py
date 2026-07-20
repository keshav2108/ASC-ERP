from getpass import getpass
from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(
        0,
        str(PROJECT_ROOT),
    )


from app.auth.password import hash_password
from app.database import SessionLocal
from app.models.user import User


def prompt_password() -> str:
    while True:
        password = getpass(
            "Enter new Admin password: "
        )

        confirmation = getpass(
            "Confirm new Admin password: "
        )

        if password != confirmation:
            print(
                "Passwords do not match. "
                "Please try again."
            )
            continue

        if len(password) < 8:
            print(
                "Password must contain at least "
                "8 characters."
            )
            continue

        if len(password) > 128:
            print(
                "Password cannot exceed "
                "128 characters."
            )
            continue

        return password


def main() -> int:
    db = SessionLocal()

    try:
        admins = (
            db.query(User)
            .filter(User.role == "ADMIN")
            .order_by(User.id.asc())
            .all()
        )

        if not admins:
            print("No Admin account was found.")
            return 1

        if len(admins) > 1:
            print(
                "Multiple Admin accounts were found. "
                "Password reset cancelled."
            )

            for admin in admins:
                print(
                    admin.employee_id,
                    admin.username,
                    admin.mobile,
                )

            return 1

        admin = admins[0]

        print()
        print("Admin account found:")
        print(
            f"Employee ID: {admin.employee_id}"
        )
        print(
            f"Full name: {admin.full_name}"
        )
        print(
            f"Username: {admin.username}"
        )
        print(
            f"Mobile: {admin.mobile}"
        )
        print()

        new_password = prompt_password()

        admin.password_hash = hash_password(
            new_password
        )

        admin.status = "ACTIVE"

        db.commit()

        print()
        print(
            "Admin password reset successfully."
        )
        print(
            "Login using username "
            f"'{admin.username}' or mobile "
            f"'{admin.mobile}'."
        )

        return 0

    except Exception as error:
        db.rollback()

        print()
        print(
            "Password reset failed:",
            error,
        )

        return 1

    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
