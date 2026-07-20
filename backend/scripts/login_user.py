from getpass import getpass
import json
from pathlib import Path
import re
import urllib.error
import urllib.request


LOGIN_URL = (
    "http://127.0.0.1:8000"
    "/api/v1/auth/login"
)


def safe_token_name(
    account_name: str,
) -> str:
    normalized_name = re.sub(
        r"[^a-z0-9]+",
        "_",
        account_name.strip().lower(),
    ).strip("_")

    return normalized_name or "user"


def main() -> int:
    print()
    print("ASC Manager - User Login")
    print("------------------------")

    account_name = input(
        "Token name "
        "[service_manager]: "
    ).strip()

    if not account_name:
        account_name = "service_manager"

    login_id = input(
        "Username or mobile number: "
    ).strip()

    password = getpass(
        "Password: "
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
                response.read().decode(
                    "utf-8"
                )
            )

    except urllib.error.HTTPError as error:
        response_text = error.read().decode(
            "utf-8"
        )

        print()
        print(
            f"Login failed with HTTP "
            f"{error.code}:"
        )
        print(response_text)

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

        return 1

    token_file = Path(
        "/tmp/"
        f"asc_{safe_token_name(account_name)}"
        "_token"
    )

    token_file.write_text(
        access_token,
        encoding="utf-8",
    )

    token_file.chmod(0o600)

    print()
    print("Login successful.")
    print(
        f"Token saved to: {token_file}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
