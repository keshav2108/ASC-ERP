from __future__ import annotations

import argparse
import sys
from datetime import timedelta
from decimal import Decimal
from pathlib import Path

from sqlalchemy.orm import Session


# Allow this script to import the app package when executed from scripts/.
BACKEND_ROOT = Path(__file__).resolve().parents[1]

if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))


import app.models  # noqa: E402,F401
from app.database import SessionLocal, engine  # noqa: E402
from app.models.customer import Customer  # noqa: E402
from app.models.customer_product import CustomerProduct  # noqa: E402
from app.models.job_card import JobCard  # noqa: E402
from app.models.service_request import ServiceRequest  # noqa: E402
from app.models.spare_part import SparePart  # noqa: E402
from app.models.stock_transaction import StockTransaction  # noqa: E402
from app.utils.timezone import get_current_time  # noqa: E402


SEED_MARKER = "ASC-DUMMY-SEED-V1"

CUSTOMER_COUNT = 20

CITIES = [
    ("Indore", "452001"),
    ("Bhopal", "462001"),
    ("Patna", "800001"),
    ("Delhi", "110001"),
    ("Mumbai", "400001"),
]

PRODUCTS = [
    ("Pigeon", "Mixer Grinder"),
    ("Kutchina", "Kitchen Chimney"),
    ("Bajaj", "Ceiling Fan"),
    ("Philips", "Electric Kettle"),
    ("Prestige", "Induction Cooktop"),
    ("Pigeon", "Rice Cooker"),
    ("Samsung", "Microwave Oven"),
    ("Kent", "Water Purifier"),
    ("Philips", "Toaster"),
    ("Bajaj", "Juicer"),
]

COMPLAINTS = [
    ("ELECTRICAL", "Appliance is not powering on."),
    ("MECHANICAL", "Unusual noise is coming during operation."),
    ("ELECTRICAL", "Motor stops after running for a few minutes."),
    ("OTHER", "Performance is lower than expected."),
    ("MECHANICAL", "Internal moving part appears to be jammed."),
    ("ELECTRICAL", "Power indicator works but appliance does not start."),
    ("OTHER", "Customer requested a complete inspection."),
    ("MECHANICAL", "Excessive vibration occurs during operation."),
    ("ELECTRICAL", "Power cable or internal connection may be faulty."),
    ("OTHER", "Appliance requires routine servicing and testing."),
]

SPARE_PARTS = [
    {
        "part_name": "[TEST] Mixer Grinder Motor",
        "brand": "Pigeon",
        "product_category": "Mixer Grinder",
        "purchase_price": Decimal("850.00"),
        "selling_price": Decimal("1200.00"),
        "current_stock": 15,
        "minimum_stock": 5,
    },
    {
        "part_name": "[TEST] Carbon Brush Set",
        "brand": "Universal",
        "product_category": "Mixer Grinder",
        "purchase_price": Decimal("90.00"),
        "selling_price": Decimal("180.00"),
        "current_stock": 35,
        "minimum_stock": 10,
    },
    {
        "part_name": "[TEST] Heating Element",
        "brand": "Philips",
        "product_category": "Electric Kettle",
        "purchase_price": Decimal("280.00"),
        "selling_price": Decimal("450.00"),
        "current_stock": 18,
        "minimum_stock": 5,
    },
    {
        "part_name": "[TEST] Induction Cooling Fan",
        "brand": "Prestige",
        "product_category": "Induction Cooktop",
        "purchase_price": Decimal("320.00"),
        "selling_price": Decimal("550.00"),
        "current_stock": 12,
        "minimum_stock": 4,
    },
    {
        "part_name": "[TEST] Chimney Control Board",
        "brand": "Kutchina",
        "product_category": "Kitchen Chimney",
        "purchase_price": Decimal("1250.00"),
        "selling_price": Decimal("1850.00"),
        "current_stock": 8,
        "minimum_stock": 3,
    },
    {
        "part_name": "[TEST] Ceiling Fan Capacitor",
        "brand": "Bajaj",
        "product_category": "Ceiling Fan",
        "purchase_price": Decimal("75.00"),
        "selling_price": Decimal("150.00"),
        "current_stock": 40,
        "minimum_stock": 12,
    },
    {
        "part_name": "[TEST] Microwave Door Switch",
        "brand": "Samsung",
        "product_category": "Microwave Oven",
        "purchase_price": Decimal("160.00"),
        "selling_price": Decimal("300.00"),
        "current_stock": 20,
        "minimum_stock": 6,
    },
    {
        "part_name": "[TEST] Water Purifier Pump",
        "brand": "Kent",
        "product_category": "Water Purifier",
        "purchase_price": Decimal("950.00"),
        "selling_price": Decimal("1450.00"),
        "current_stock": 10,
        "minimum_stock": 3,
    },
    {
        "part_name": "[TEST] Thermal Fuse",
        "brand": "Universal",
        "product_category": "Electrical Appliance",
        "purchase_price": Decimal("35.00"),
        "selling_price": Decimal("90.00"),
        "current_stock": 50,
        "minimum_stock": 15,
    },
    {
        "part_name": "[TEST] Power Cord",
        "brand": "Universal",
        "product_category": "Electrical Appliance",
        "purchase_price": Decimal("110.00"),
        "selling_price": Decimal("220.00"),
        "current_stock": 30,
        "minimum_stock": 10,
    },
]


def _next_dated_sequence(
    db: Session,
    column,
    prefix: str,
) -> tuple[str, int]:
    date_token = get_current_time().strftime("%Y%m%d")
    code_stem = f"{prefix}{date_token}"

    existing_codes = (
        db.query(column)
        .filter(column.like(f"{code_stem}%"))
        .all()
    )

    highest_sequence = 0

    for row in existing_codes:
        code = row[0]

        if not code or not code.startswith(code_stem):
            continue

        suffix = code[len(code_stem):]

        if suffix.isdigit():
            highest_sequence = max(
                highest_sequence,
                int(suffix),
            )

    return code_stem, highest_sequence + 1


def _next_part_sequence(
    db: Session,
) -> int:
    existing_codes = (
        db.query(SparePart.part_code)
        .filter(SparePart.part_code.like("PART%"))
        .all()
    )

    highest_sequence = 0

    for row in existing_codes:
        code = row[0]

        if not code:
            continue

        suffix = code.removeprefix("PART")

        if suffix.isdigit():
            highest_sequence = max(
                highest_sequence,
                int(suffix),
            )

    return highest_sequence + 1


def _customer_email(index: int) -> str:
    return f"asc.seed.customer{index:02d}@example.com"


def _customer_mobile(index: int) -> str:
    return f"70000000{index:02d}"


def _product_serial(index: int) -> str:
    return f"ASC-SEED-SN-{index:03d}"


def _request_marker(index: int) -> str:
    return f"[{SEED_MARKER}:{index:02d}]"


def _opening_reference(index: int) -> str:
    return f"{SEED_MARKER}-OPENING-{index:02d}"


def seed_data() -> None:
    db = SessionLocal()

    created = {
        "customers": 0,
        "products": 0,
        "service_requests": 0,
        "spare_parts": 0,
        "stock_transactions": 0,
    }

    reused = {
        "customers": 0,
        "products": 0,
        "service_requests": 0,
        "spare_parts": 0,
        "stock_transactions": 0,
    }

    try:
        now = get_current_time()

        customer_stem, next_customer_sequence = (
            _next_dated_sequence(
                db,
                Customer.customer_code,
                "CUS",
            )
        )

        request_stem, next_request_sequence = (
            _next_dated_sequence(
                db,
                ServiceRequest.request_code,
                "SR",
            )
        )

        next_part_sequence = _next_part_sequence(db)

        for index in range(1, CUSTOMER_COUNT + 1):
            email = _customer_email(index)
            mobile = _customer_mobile(index)

            customer = (
                db.query(Customer)
                .filter(Customer.mobile == mobile)
                .first()
            )

            if customer:
                if customer.email != email:
                    raise RuntimeError(
                        f"Mobile {mobile} already belongs to "
                        "a non-seed customer."
                    )

                reused["customers"] += 1

            else:
                city, pincode = CITIES[
                    (index - 1) % len(CITIES)
                ]

                customer = Customer(
                    customer_code=(
                        f"{customer_stem}"
                        f"{next_customer_sequence:03d}"
                    ),
                    full_name=f"Test Customer {index:02d}",
                    mobile=mobile,
                    alternate_mobile=None,
                    email=email,
                    address=(
                        f"Test Address {index:02d}, "
                        "ASC Sample Road"
                    ),
                    city=city,
                    pincode=pincode,
                    status="ACTIVE",
                )

                next_customer_sequence += 1

                db.add(customer)
                db.flush()

                created["customers"] += 1

            brand, product_name = PRODUCTS[
                (index - 1) % len(PRODUCTS)
            ]

            serial_number = _product_serial(index)

            product = (
                db.query(CustomerProduct)
                .filter(
                    CustomerProduct.serial_number
                    == serial_number
                )
                .first()
            )

            if product:
                if product.customer_id != customer.id:
                    raise RuntimeError(
                        f"Serial {serial_number} belongs "
                        "to another customer."
                    )

                reused["products"] += 1

            else:
                product = CustomerProduct(
                    customer_id=customer.id,
                    brand=brand,
                    product_name=product_name,
                    model_number=f"TEST-MDL-{index:03d}",
                    serial_number=serial_number,
                    purchase_date=(
                        now - timedelta(days=30 * index)
                    ),
                    warranty_status=(
                        "IN"
                        if index % 2 == 1
                        else "OUT"
                    ),
                )

                db.add(product)
                db.flush()

                created["products"] += 1

            category, description = COMPLAINTS[
                (index - 1) % len(COMPLAINTS)
            ]

            marker = _request_marker(index)

            existing_request = (
                db.query(ServiceRequest)
                .filter(
                    ServiceRequest.complaint_description.like(
                        f"{marker}%"
                    )
                )
                .first()
            )

            if existing_request:
                if (
                    existing_request.customer_id != customer.id
                    or existing_request.customer_product_id
                    != product.id
                ):
                    raise RuntimeError(
                        f"Seed marker {marker} is linked "
                        "to unexpected records."
                    )

                reused["service_requests"] += 1

            else:
                service_request = ServiceRequest(
                    request_code=(
                        f"{request_stem}"
                        f"{next_request_sequence:03d}"
                    ),
                    customer_id=customer.id,
                    customer_product_id=product.id,
                    complaint_category=category,
                    complaint_description=(
                        f"{marker} {description}"
                    ),
                    received_accessories=(
                        "Power cable"
                        if index % 3 == 0
                        else None
                    ),
                    product_condition=(
                        "DAMAGED"
                        if index % 7 == 0
                        else (
                            "PARTS_MISSING"
                            if index % 5 == 0
                            else "GOOD"
                        )
                    ),
                    priority=(
                        "HIGH"
                        if index % 5 == 0
                        else (
                            "LOW"
                            if index % 4 == 0
                            else "NORMAL"
                        )
                    ),
                    status="OPEN",
                    estimated_delivery=(
                        now
                        + timedelta(
                            days=2 + (index % 4)
                        )
                    ),
                )

                next_request_sequence += 1

                db.add(service_request)
                db.flush()

                created["service_requests"] += 1

        for index, specification in enumerate(
            SPARE_PARTS,
            start=1,
        ):
            part = (
                db.query(SparePart)
                .filter(
                    SparePart.part_name
                    == specification["part_name"],
                    SparePart.brand
                    == specification["brand"],
                )
                .first()
            )

            if part:
                reused["spare_parts"] += 1

            else:
                part = SparePart(
                    part_code=f"PART{next_part_sequence:03d}",
                    part_name=specification["part_name"],
                    brand=specification["brand"],
                    product_category=(
                        specification["product_category"]
                    ),
                    unit="PIECE",
                    purchase_price=(
                        specification["purchase_price"]
                    ),
                    selling_price=(
                        specification["selling_price"]
                    ),
                    current_stock=(
                        specification["current_stock"]
                    ),
                    minimum_stock=(
                        specification["minimum_stock"]
                    ),
                    is_active=True,
                )

                next_part_sequence += 1

                db.add(part)
                db.flush()

                created["spare_parts"] += 1

            reference = _opening_reference(index)

            opening_transaction = (
                db.query(StockTransaction)
                .filter(
                    StockTransaction.reference == reference
                )
                .first()
            )

            if opening_transaction:
                if opening_transaction.spare_part_id != part.id:
                    raise RuntimeError(
                        f"Opening reference {reference} "
                        "belongs to another spare part."
                    )

                reused["stock_transactions"] += 1

            else:
                other_transactions = (
                    db.query(StockTransaction)
                    .filter(
                        StockTransaction.spare_part_id
                        == part.id
                    )
                    .count()
                )

                if other_transactions:
                    raise RuntimeError(
                        f"{part.part_name} exists with stock "
                        "history but without the seed opening "
                        "reference."
                    )

                expected_stock = specification[
                    "current_stock"
                ]

                if part.current_stock != expected_stock:
                    raise RuntimeError(
                        f"{part.part_name} has unexpected "
                        f"stock {part.current_stock}."
                    )

                transaction = StockTransaction(
                    spare_part_id=part.id,
                    job_card_id=None,
                    transaction_type="OPENING",
                    quantity=expected_stock,
                    unit_price=specification[
                        "purchase_price"
                    ],
                    line_total=(
                        specification["purchase_price"]
                        * expected_stock
                    ),
                    reference=reference,
                    remarks=(
                        "Opening stock created by "
                        f"{SEED_MARKER}"
                    ),
                )

                db.add(transaction)
                created["stock_transactions"] += 1

        db.commit()

        print("Dummy seed completed successfully.")
        print()
        print("Created:")
        for key, value in created.items():
            print(f"  {key}: {value}")

        print()
        print("Already existed and reused:")
        for key, value in reused.items():
            print(f"  {key}: {value}")

        print()
        print(
            "All seeded Service Requests remain OPEN "
            "without Job Cards."
        )

    except Exception:
        db.rollback()
        raise

    finally:
        db.close()


def cleanup_data() -> None:
    db = SessionLocal()

    try:
        request_markers = [
            _request_marker(index)
            for index in range(1, CUSTOMER_COUNT + 1)
        ]

        seed_requests = (
            db.query(ServiceRequest)
            .filter(
                ServiceRequest.complaint_description.like(
                    f"[{SEED_MARKER}:%"
                )
            )
            .all()
        )

        request_ids = [
            service_request.id
            for service_request in seed_requests
        ]

        if request_ids:
            linked_job_cards = (
                db.query(JobCard)
                .filter(
                    JobCard.service_request_id.in_(
                        request_ids
                    )
                )
                .count()
            )

            if linked_job_cards:
                raise RuntimeError(
                    "Cleanup stopped: one or more seeded "
                    "Service Requests already have Job Cards."
                )

        for service_request in seed_requests:
            db.delete(service_request)

        db.flush()

        serial_numbers = [
            _product_serial(index)
            for index in range(1, CUSTOMER_COUNT + 1)
        ]

        seed_products = (
            db.query(CustomerProduct)
            .filter(
                CustomerProduct.serial_number.in_(
                    serial_numbers
                )
            )
            .all()
        )

        for product in seed_products:
            remaining_requests = (
                db.query(ServiceRequest)
                .filter(
                    ServiceRequest.customer_product_id
                    == product.id
                )
                .count()
            )

            if remaining_requests:
                raise RuntimeError(
                    f"Cleanup stopped: {product.serial_number} "
                    "still has a Service Request."
                )

            db.delete(product)

        db.flush()

        seed_emails = [
            _customer_email(index)
            for index in range(1, CUSTOMER_COUNT + 1)
        ]

        seed_customers = (
            db.query(Customer)
            .filter(Customer.email.in_(seed_emails))
            .all()
        )

        for customer in seed_customers:
            remaining_products = (
                db.query(CustomerProduct)
                .filter(
                    CustomerProduct.customer_id
                    == customer.id
                )
                .count()
            )

            remaining_requests = (
                db.query(ServiceRequest)
                .filter(
                    ServiceRequest.customer_id
                    == customer.id
                )
                .count()
            )

            if remaining_products or remaining_requests:
                raise RuntimeError(
                    f"Cleanup stopped: {customer.full_name} "
                    "still has linked business data."
                )

            db.delete(customer)

        seed_part_names = [
            specification["part_name"]
            for specification in SPARE_PARTS
        ]

        seed_parts = (
            db.query(SparePart)
            .filter(
                SparePart.part_name.in_(seed_part_names)
            )
            .all()
        )

        for part in seed_parts:
            transactions = (
                db.query(StockTransaction)
                .filter(
                    StockTransaction.spare_part_id
                    == part.id
                )
                .all()
            )

            for transaction in transactions:
                is_seed_opening = (
                    transaction.transaction_type == "OPENING"
                    and transaction.job_card_id is None
                    and transaction.reference is not None
                    and transaction.reference.startswith(
                        f"{SEED_MARKER}-OPENING-"
                    )
                )

                if not is_seed_opening:
                    raise RuntimeError(
                        f"Cleanup stopped: {part.part_name} "
                        "has non-seed stock usage."
                    )

            for transaction in transactions:
                db.delete(transaction)

            db.delete(part)

        db.commit()

        print("Dummy seed cleanup completed successfully.")
        print(f"Deleted Service Requests: {len(seed_requests)}")
        print(f"Deleted products: {len(seed_products)}")
        print(f"Deleted customers: {len(seed_customers)}")
        print(f"Deleted spare parts: {len(seed_parts)}")

    except Exception:
        db.rollback()
        raise

    finally:
        db.close()


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Create or remove ASC Manager dummy test data."
        )
    )

    parser.add_argument(
        "action",
        choices=("seed", "cleanup"),
        nargs="?",
        default="seed",
    )

    args = parser.parse_args()

    # Keep script output readable even though development engine
    # logging is enabled globally.
    engine.echo = False

    if args.action == "seed":
        seed_data()
    else:
        cleanup_data()


if __name__ == "__main__":
    main()
