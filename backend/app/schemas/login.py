from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(
        min_length=3,
        description="Username or registered mobile number",
    )
    password: str = Field(
        min_length=1,
    )
