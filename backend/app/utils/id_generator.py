from app.utils.timezone import IST
from datetime import datetime


def generate_code(
    prefix: str,
    sequence: int
):

    today = datetime.now(IST)

    return (
        f"{prefix}"
        f"{today.strftime('%Y%m%d')}"
        f"{sequence:03d}"
    )
