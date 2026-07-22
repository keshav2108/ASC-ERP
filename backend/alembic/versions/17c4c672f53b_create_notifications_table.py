"""create notifications table

Revision ID: 17c4c672f53b
Revises: 4a01adcaafb1
Create Date: 2026-07-22 07:01:52.802320
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Revision identifiers used by Alembic.
revision: str = "17c4c672f53b"
down_revision: Union[str, Sequence[str], None] = "4a01adcaafb1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create the notifications table."""

    op.create_table(
        "notifications",
        sa.Column(
            "id",
            sa.Integer(),
            autoincrement=True,
            nullable=False,
        ),
        sa.Column(
            "recipient_user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "created_by_user_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "notification_type",
            sa.String(length=50),
            nullable=False,
        ),
        sa.Column(
            "title",
            sa.String(length=150),
            nullable=False,
        ),
        sa.Column(
            "message",
            sa.Text(),
            nullable=False,
        ),
        sa.Column(
            "entity_type",
            sa.String(length=50),
            nullable=True,
        ),
        sa.Column(
            "entity_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
        ),
        sa.Column(
            "read_at",
            sa.DateTime(),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["users.id"],
        ),
        sa.ForeignKeyConstraint(
            ["recipient_user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_notifications_created_at",
        "notifications",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "ix_notifications_created_by_user_id",
        "notifications",
        ["created_by_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_notifications_entity_id",
        "notifications",
        ["entity_id"],
        unique=False,
    )
    op.create_index(
        "ix_notifications_entity_type",
        "notifications",
        ["entity_type"],
        unique=False,
    )
    op.create_index(
        "ix_notifications_id",
        "notifications",
        ["id"],
        unique=False,
    )
    op.create_index(
        "ix_notifications_notification_type",
        "notifications",
        ["notification_type"],
        unique=False,
    )
    op.create_index(
        "ix_notifications_recipient_user_id",
        "notifications",
        ["recipient_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_notifications_status",
        "notifications",
        ["status"],
        unique=False,
    )


def downgrade() -> None:
    """Remove the notifications table."""

    op.drop_index(
        "ix_notifications_status",
        table_name="notifications",
    )
    op.drop_index(
        "ix_notifications_recipient_user_id",
        table_name="notifications",
    )
    op.drop_index(
        "ix_notifications_notification_type",
        table_name="notifications",
    )
    op.drop_index(
        "ix_notifications_id",
        table_name="notifications",
    )
    op.drop_index(
        "ix_notifications_entity_type",
        table_name="notifications",
    )
    op.drop_index(
        "ix_notifications_entity_id",
        table_name="notifications",
    )
    op.drop_index(
        "ix_notifications_created_by_user_id",
        table_name="notifications",
    )
    op.drop_index(
        "ix_notifications_created_at",
        table_name="notifications",
    )

    op.drop_table("notifications")
