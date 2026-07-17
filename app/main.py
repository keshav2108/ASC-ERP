from fastapi import FastAPI

from app.routes.auth import router as auth_router


app = FastAPI(
    title="ASC-ERP API",
    description="Shree Sai Nath Enterprises ASC Management System"
)


app.include_router(auth_router)


@app.get("/")
def home():

    return {
        "company": "Shree Sai Nath Enterprises",
        "message": "ASC Manager API Running"
    }
