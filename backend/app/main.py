from fastapi import FastAPI

from app.routes.auth import router as auth_router
from app.routes.customer import router as customer_router
from app.routes.customer_product import (
    router as customer_product_router,
)
from app.routes.inventory import router as inventory_router
from app.routes.invoice import router as invoice_router
from app.routes.job_card import router as job_card_router
from app.routes.master_option import (
    router as master_option_router,
)
from app.routes.service_request import (
    router as service_request_router,
)
from app.routes.spare_part import router as spare_part_router
from app.routes.technician import router as technician_router
from app.routes.workflow_transition import (
    router as workflow_transition_router,
)
from app.routes.payment import router as payment_router
from app.routes.delivery import router as delivery_router
from app.routes.dashboard import router as dashboard_router


app = FastAPI(
    title="ASC-ERP API",
    description=(
        "Shree Sai Nath Enterprises "
        "Authorized Service Centre Management System"
    ),
)


app.include_router(auth_router)
app.include_router(customer_router)
app.include_router(customer_product_router)
app.include_router(service_request_router)
app.include_router(master_option_router)
app.include_router(technician_router)
app.include_router(job_card_router)
app.include_router(workflow_transition_router)
app.include_router(spare_part_router)
app.include_router(inventory_router)
app.include_router(invoice_router)
app.include_router(payment_router)
app.include_router(delivery_router)
app.include_router(dashboard_router)


@app.get("/")
def home():
    return {
        "company": "Shree Sai Nath Enterprises",
        "message": "ASC Manager API Running",
    }
