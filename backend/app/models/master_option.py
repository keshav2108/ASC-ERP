from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Integer,
    String,
    UniqueConstraint,
)

from app.database import Base
from app.utils.timezone import get_current_time


class MasterOption(Base):
    __tablename__ = "master_options"

    __table_args__ = (
        UniqueConstraint(
            "option_type",
            "code",
            name="uq_master_option_type_code",
        ),
    )

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    option_type = Column(
        String(50),
        nullable=False,
        index=True,
    )

    code = Column(
        String(50),
        nullable=False,
    )

    label = Column(
        String(100),
        nullable=False,
    )

    display_order = Column(
        Integer,
        nullable=False,
        default=0,
    )

    is_active = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=get_current_time,
    )
