from datetime import datetime


def generate_employee_id(sequence: int):

    today = datetime.now()

    return (
        f"EMP"
        f"{today.strftime('%Y%m%d')}"
        f"{sequence:03d}"
    )
