from pydantic import BaseModel, EmailStr
from typing import Optional


class UserCreate(BaseModel):
    full_name: str
    mobile: str
    password: str
    email: Optional[EmailStr] = None
    role: str = "ADMIN"


class UserResponse(BaseModel):
    employee_id: str
    full_name: str
    mobile: str
    email: Optional[str]
    role: str
    status: str

    class Config:
        from_attributes = True
