from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel


class DashboardSummary(BaseModel):
    total_customers: int
    total_service_requests: int
    open_service_requests: int
    active_jobs: int
    completed_jobs: int
    delivered_jobs: int
    active_technicians: int
    technicians_with_active_jobs: int
    low_stock_parts: int
    unpaid_invoices: int
    partially_paid_invoices: int
    total_revenue: Decimal


class StatusCount(BaseModel):
    status: str
    count: int


class RevenuePoint(BaseModel):
    date: date
    amount: Decimal


class LowStockPart(BaseModel):
    id: int
    part_code: str
    part_name: str
    brand: str | None
    current_stock: int
    minimum_stock: int
    unit: str


class RecentServiceRequest(BaseModel):
    id: int
    request_code: str
    customer_name: str
    customer_mobile: str
    product_name: str
    brand: str
    complaint_category: str
    priority: str
    status: str
    created_at: datetime


class TechnicianWorkload(BaseModel):
    technician_id: int
    technician_code: str
    technician_name: str
    availability_status: str
    active_jobs: int


class DashboardOverviewResponse(BaseModel):
    summary: DashboardSummary

    service_request_statuses: list[StatusCount]

    job_statuses: list[StatusCount]

    revenue_last_7_days: list[RevenuePoint]

    low_stock_parts: list[LowStockPart]

    recent_service_requests: list[RecentServiceRequest]

    technician_workload: list[TechnicianWorkload]
