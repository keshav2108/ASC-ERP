from datetime import timedelta
from decimal import Decimal

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.invoice import Invoice
from app.models.job_card import JobCard
from app.models.payment import Payment
from app.models.service_request import ServiceRequest
from app.models.spare_part import SparePart
from app.models.technician import Technician
from app.utils.timezone import get_current_time


ACTIVE_JOB_STATUSES = {
    "ASSIGNED",
    "ACCEPTED",
    "DIAGNOSIS",
    "WAITING_PARTS",
    "REPAIR_IN_PROGRESS",
    "TESTING",
}


def decimal_value(
    value,
) -> Decimal:
    if value is None:
        return Decimal("0.00")

    return Decimal(str(value)).quantize(
        Decimal("0.01")
    )


def get_status_counts(
    db: Session,
    model,
):
    rows = (
        db.query(
            model.status,
            func.count(model.id),
        )
        .group_by(model.status)
        .order_by(model.status.asc())
        .all()
    )

    return [
        {
            "status": row[0],
            "count": row[1],
        }
        for row in rows
    ]


def get_revenue_last_7_days(
    db: Session,
):
    today = get_current_time().date()

    start_date = today - timedelta(days=6)

    rows = (
        db.query(
            func.date(Payment.paid_at).label(
                "payment_date"
            ),
            func.coalesce(
                func.sum(Payment.amount),
                0,
            ).label("amount"),
        )
        .filter(
            Payment.status == "SUCCESS",
            func.date(Payment.paid_at)
            >= start_date,
        )
        .group_by(
            func.date(Payment.paid_at)
        )
        .all()
    )

    revenue_map = {
        row.payment_date: decimal_value(
            row.amount
        )
        for row in rows
    }

    result = []

    for day_offset in range(7):
        current_date = (
            start_date
            + timedelta(days=day_offset)
        )

        result.append(
            {
                "date": current_date,
                "amount": revenue_map.get(
                    current_date,
                    Decimal("0.00"),
                ),
            }
        )

    return result


def get_low_stock_parts(
    db: Session,
):
    parts = (
        db.query(SparePart)
        .filter(
            SparePart.is_active.is_(True),
            SparePart.current_stock
            <= SparePart.minimum_stock,
        )
        .order_by(
            SparePart.current_stock.asc(),
            SparePart.part_name.asc(),
        )
        .limit(10)
        .all()
    )

    return [
        {
            "id": part.id,
            "part_code": part.part_code,
            "part_name": part.part_name,
            "brand": part.brand,
            "current_stock": part.current_stock,
            "minimum_stock": part.minimum_stock,
            "unit": part.unit,
        }
        for part in parts
    ]


def get_recent_service_requests(
    db: Session,
):
    service_requests = (
        db.query(ServiceRequest)
        .order_by(
            ServiceRequest.id.desc()
        )
        .limit(10)
        .all()
    )

    result = []

    for service_request in service_requests:
        customer = service_request.customer
        product = service_request.customer_product

        result.append(
            {
                "id": service_request.id,
                "request_code": (
                    service_request.request_code
                ),
                "customer_name": (
                    customer.full_name
                    if customer
                    else "Unknown"
                ),
                "customer_mobile": (
                    customer.mobile
                    if customer
                    else ""
                ),
                "product_name": (
                    product.product_name
                    if product
                    else "Unknown"
                ),
                "brand": (
                    product.brand
                    if product
                    else ""
                ),
                "complaint_category": (
                    service_request
                    .complaint_category
                ),
                "priority": (
                    service_request.priority
                ),
                "status": (
                    service_request.status
                ),
                "created_at": (
                    service_request.created_at
                ),
            }
        )

    return result


def get_technician_workload(
    db: Session,
):
    technicians = (
        db.query(Technician)
        .filter(
            Technician.status == "ACTIVE"
        )
        .order_by(
            Technician.full_name.asc()
        )
        .all()
    )

    result = []

    for technician in technicians:
        active_jobs = (
            db.query(func.count(JobCard.id))
            .filter(
                JobCard.technician_id
                == technician.id,
                JobCard.status.in_(
                    ACTIVE_JOB_STATUSES
                ),
            )
            .scalar()
            or 0
        )

        result.append(
            {
                "technician_id": technician.id,
                "technician_code": (
                    technician.technician_code
                ),
                "technician_name": (
                    technician.full_name
                ),
                "availability_status": (
                    technician
                    .availability_status
                ),
                "active_jobs": active_jobs,
            }
        )

    return result


def get_dashboard_overview(
    db: Session,
):
    total_customers = (
        db.query(func.count(Customer.id))
        .scalar()
        or 0
    )

    total_service_requests = (
        db.query(
            func.count(ServiceRequest.id)
        )
        .scalar()
        or 0
    )

    open_service_requests = (
        db.query(
            func.count(ServiceRequest.id)
        )
        .filter(
            ServiceRequest.status == "OPEN"
        )
        .scalar()
        or 0
    )

    active_jobs = (
        db.query(func.count(JobCard.id))
        .filter(
            JobCard.status.in_(
                ACTIVE_JOB_STATUSES
            )
        )
        .scalar()
        or 0
    )

    completed_jobs = (
        db.query(func.count(JobCard.id))
        .filter(
            JobCard.status == "COMPLETED"
        )
        .scalar()
        or 0
    )

    delivered_jobs = (
        db.query(func.count(JobCard.id))
        .filter(
            JobCard.status == "DELIVERED"
        )
        .scalar()
        or 0
    )

    available_technicians = (
        db.query(func.count(Technician.id))
        .filter(
            Technician.status == "ACTIVE",
            Technician.availability_status
            == "AVAILABLE",
        )
        .scalar()
        or 0
    )

    busy_technicians = (
        db.query(func.count(Technician.id))
        .filter(
            Technician.status == "ACTIVE",
            Technician.availability_status
            == "BUSY",
        )
        .scalar()
        or 0
    )

    low_stock_parts_count = (
        db.query(func.count(SparePart.id))
        .filter(
            SparePart.is_active.is_(True),
            SparePart.current_stock
            <= SparePart.minimum_stock,
        )
        .scalar()
        or 0
    )

    unpaid_invoices = (
        db.query(func.count(Invoice.id))
        .filter(
            Invoice.status != "CANCELLED",
            Invoice.payment_status == "UNPAID",
        )
        .scalar()
        or 0
    )

    partially_paid_invoices = (
        db.query(func.count(Invoice.id))
        .filter(
            Invoice.status != "CANCELLED",
            Invoice.payment_status
            == "PARTIALLY_PAID",
        )
        .scalar()
        or 0
    )

    total_revenue = (
        db.query(
            func.coalesce(
                func.sum(Payment.amount),
                0,
            )
        )
        .filter(
            Payment.status == "SUCCESS"
        )
        .scalar()
    )

    return {
        "summary": {
            "total_customers": (
                total_customers
            ),
            "total_service_requests": (
                total_service_requests
            ),
            "open_service_requests": (
                open_service_requests
            ),
            "active_jobs": active_jobs,
            "completed_jobs": completed_jobs,
            "delivered_jobs": delivered_jobs,
            "available_technicians": (
                available_technicians
            ),
            "busy_technicians": (
                busy_technicians
            ),
            "low_stock_parts": (
                low_stock_parts_count
            ),
            "unpaid_invoices": (
                unpaid_invoices
            ),
            "partially_paid_invoices": (
                partially_paid_invoices
            ),
            "total_revenue": decimal_value(
                total_revenue
            ),
        },
        "service_request_statuses": (
            get_status_counts(
                db,
                ServiceRequest,
            )
        ),
        "job_statuses": get_status_counts(
            db,
            JobCard,
        ),
        "revenue_last_7_days": (
            get_revenue_last_7_days(db)
        ),
        "low_stock_parts": (
            get_low_stock_parts(db)
        ),
        "recent_service_requests": (
            get_recent_service_requests(db)
        ),
        "technician_workload": (
            get_technician_workload(db)
        ),
    }
