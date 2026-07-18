from fastapi import FastAPI

from app.routes.auth import router as auth_router
from app.routes.customer import router as customer_router
from app.routes.customer_product import router as customer_product_router
from app.routes.service_request import router as service_request_router
from app.routes.master_option import router as master_option_router


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


@app.get("/")
def home():
    return {
        "company": "Shree Sai Nath Enterprises",
        "message": "ASC Manager API Running",
    }
