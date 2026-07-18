from pydantic import BaseModel


class LoginRequest(BaseModel):
    mobile: str
    password: str
