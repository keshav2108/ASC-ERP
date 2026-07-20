from getpass import getpass
import json
from pathlib import Path
import urllib.error
import urllib.request


REGISTER_URL = (
    "http://127.0.0.1:8000"
    "/api/v1/auth/register"
)

ADMIN_TOKEN_FILE = Path(
    "/tmp/asc_admin_token"
)

ALLOWED_ROLES = {
    "ADMIN",
    "SERVICE_MANAGER",
    "SERVICE_EXECUTIVE",
    "TECHNICIAN",
    "ACCOUNTANT",
}


def prompt_required(
    label: str,
) -> str:
    while True:
        value = input(label).strip()

        if value:
            return value

        print("This field is required.")


def prompt_role() -> str:
    while True:
        value = input(
            "Role [SERVICE_MANAGER]: "
        ).strip()

        if not value:
            return "SERVICE_MANAGER"

        normalized_role = (
            value.upper()
            .replace("-", "_")
            .replace(" ", "_")
        )

        if normalized_role in ALLOWED_ROLES:
            return normalized_role

        print(
            "Invalid role. Allowed roles:"
        )

        for role in sorted(ALLOWED_ROLES):
            print(f"- {role}")


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


def load_admin_token() -> str:
    if not ADMIN_TOKEN_FILE.exists():
        raise RuntimeError(
            "Admin token file was not found. "
            "Run the Admin login script first."
        )

    token = ADMIN_TOKEN_FILE.read_text(
        encoding="utf-8"
    ).strip()

    if not token:
        raise RuntimeError(
            "Admin token file is empty."
        )

    return token


def print_error_response(
    error: urllib.error.HTTPError,
) -> None:
    response_text = error.read().decode(
        "utf-8"
    )

    print()
    print(
        f"Registration failed with "
        f"HTTP {error.code}:"
    )

    try:
        response_data = json.loads(
            response_text
        )

        print(
            json.dumps(
                response_data,
                indent=2,
            )
        )

    except json.JSONDecodeError:
        print(response_text)


def main() -> int:
    print()
    print("ASC Manager - Register User")
    print("---------------------------")

    try:
        admin_token = load_admin_token()

    except RuntimeError as error:
        print(error)
        return 1

    full_name = prompt_required(
        "Full name: "
    )

    mobile = prompt_required(
        "Mobile number: "
    )

    email_value = input(
        "Email address (optional): "
    ).strip()

    role = prompt_role()
    password = prompt_password()

    payload = {
        "full_name": full_name,
        "mobile": mobile,
        "email": email_value or None,
        "password": password,
        "role": role,
    }

    request = urllib.request.Request(
        REGISTER_URL,
        data=json.dumps(
            payload
        ).encode("utf-8"),
        headers={
            "Authorization": (
                f"Bearer {admin_token}"
            ),
            "Content-Type": (
                "application/json"
            ),
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(
            request,
            timeout=15,
        ) as response:
            response_data = json.loads(
                response.read().decode(
                    "utf-8"
                )
            )

    except urllib.error.HTTPError as error:
        print_error_response(error)
        return 1

    except urllib.error.URLError as error:
        print()
        print(
            "Could not connect to FastAPI:"
        )
        print(error.reason)

        return 1

    print()
    print("User registered successfully.")
    print(
        json.dumps(
            response_data,
            indent=2,
        )
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
