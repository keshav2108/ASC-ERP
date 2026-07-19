from app.utils.timezone import get_current_time


def generate_payment_code(
    sequence: int,
) -> str:
    today = get_current_time()

    return (
        f"PAY"
        f"{today.strftime('%Y%m%d')}"
        f"{sequence:03d}"
    )
