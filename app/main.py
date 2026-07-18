from fastapi import FastAPI

from app.routes.auth import router as auth_router
from app.routes.customer import router as customer_router
from app.routes.customer_product import router as customer_product_router


app = FastAPI(
    title="ASC-ERP API",
    description="Shree Sai Nath Enterprises ASC Management System"
)



# Authentication APIs
app.include_router(
    auth_router
)


# Customer APIs
app.include_router(
    customer_router
)


# Customer Product APIs
app.include_router(
    customer_product_router
)



@app.get("/")
def home():

    return {
        "company": "Shree Sai Nath Enterprises",
        "message": "ASC Manager API Running"
    }
