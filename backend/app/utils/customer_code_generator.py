from datetime import datetime

from app.utils.timezone import IST


def generate_customer_code(
    customer_number: int
):

    today = datetime.now(IST)

    return (
        f"CUS"
        f"{today.strftime('%Y%m%d')}"
        f"{customer_number:03d}"
    )
