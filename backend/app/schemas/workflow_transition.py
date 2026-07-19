from pydantic import BaseModel, Field


class WorkflowTransitionCreate(BaseModel):
    from_status: str = Field(
        min_length=1,
        max_length=50,
    )

    to_status: str = Field(
        min_length=1,
        max_length=50,
    )

    action: str = Field(
        min_length=2,
        max_length=100,
    )


class WorkflowTransitionUpdate(BaseModel):
    action: str | None = Field(
        default=None,
        min_length=2,
        max_length=100,
    )

    is_active: bool | None = None


class WorkflowTransitionResponse(BaseModel):
    id: int
    from_status: str
    to_status: str
    action: str
    is_active: bool

    model_config = {
        "from_attributes": True
    }
