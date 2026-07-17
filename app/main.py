from fastapi import FastAPI
from app.database import engine, Base


Base.metadata.create_all(bind=engine)


app = FastAPI(
    title="ASC Manager",
    description="Authorized Service Centre Management System",
    version="1.0"
)


@app.get("/")
def home():
    return {
        "company": "Shree Sai Nath Enterprises",
        "message": "ASC Manager API Running"
    }
