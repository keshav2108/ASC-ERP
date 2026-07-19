from sqlalchemy import (
    Boolean,
    Column,
    Integer,
    String,
)

from app.database import Base


class WorkflowTransition(Base):
    __tablename__ = "workflow_transitions"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    from_status = Column(
        String(50),
        nullable=False,
        index=True,
    )

    to_status = Column(
        String(50),
        nullable=False,
        index=True,
    )

    action = Column(
        String(100),
        nullable=False,
    )

    is_active = Column(
        Boolean,
        default=True,
        nullable=False,
    )
