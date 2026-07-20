from getpass import getpass
import json
from pathlib import Path
import urllib.error
import urllib.request


LOGIN_URL = (
    "http://127.0.0.1:8000"
    "/api/v1/auth/login"
)

TOKEN_FILE = Path("/tmp/asc_admin_token")


def main() -> int:
    login_id = input(
        "Admin mobile number: "
    ).strip()

    password = getpass(
        "Admin password: "
    )

    payload = json.dumps(
        {
            "username": login_id,
            "password": password,
        }
    ).encode("utf-8")

    request = urllib.request.Request(
        LOGIN_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(
            request,
            timeout=15,
        ) as response:
            response_data = json.loads(
                response.read().decode("utf-8")
            )

    except urllib.error.HTTPError as error:
        response_body = error.read().decode(
            "utf-8"
        )

        print()
        print(
            f"Login failed with HTTP "
            f"{error.code}:"
        )
        print(response_body)

        return 1

    except urllib.error.URLError as error:
        print()
        print(
            "Could not connect to FastAPI:"
        )
        print(error.reason)

        return 1

    access_token = response_data.get(
        "access_token"
    )

    if not access_token:
        print()
        print(
            "Login response did not contain "
            "an access token."
        )
        print(response_data)

        return 1

    TOKEN_FILE.write_text(
        access_token,
        encoding="utf-8",
    )

    TOKEN_FILE.chmod(0o600)

    print()
    print("Admin login successful.")
    print(
        f"Token saved securely to "
        f"{TOKEN_FILE}"
    )
    print(
        "Token type:",
        response_data.get(
            "token_type",
            "unknown",
        ),
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
