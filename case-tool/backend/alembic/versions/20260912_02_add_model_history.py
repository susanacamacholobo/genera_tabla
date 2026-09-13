"""Add canonical model snapshots and change events.

Revision ID: 20260912_02
Revises: 20260912_01
Create Date: 2026-09-12
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "20260912_02"
down_revision: str | None = "20260912_01"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "project_snapshots",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("project_id", sa.String(length=36), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("model_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["project_id"], ["projects.id"], name="fk_project_snapshots_project_id_projects", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_project_snapshots"),
        sa.UniqueConstraint(
            "project_id", "revision", name="uq_project_snapshots_revision"
        ),
    )
    op.create_index(
        "ix_project_snapshots_project_id", "project_snapshots", ["project_id"], unique=False
    )
    op.create_table(
        "change_events",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("project_id", sa.String(length=36), nullable=False),
        sa.Column("command_id", sa.String(length=200), nullable=False),
        sa.Column("base_revision", sa.Integer(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("command_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["project_id"], ["projects.id"], name="fk_change_events_project_id_projects", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_change_events"),
        sa.UniqueConstraint("project_id", "command_id", name="uq_change_events_command"),
        sa.UniqueConstraint("project_id", "revision", name="uq_change_events_revision"),
    )
    op.create_index(
        "ix_change_events_project_id", "change_events", ["project_id"], unique=False
    )

    op.execute(
        sa.text(
            """
            INSERT INTO project_snapshots (id, project_id, revision, model_json, created_at)
            SELECT
                id,
                id,
                revision,
                jsonb_build_object(
                    'id', id,
                    'name', name,
                    'revision', revision,
                    'classes', jsonb_build_array(),
                    'relationships', jsonb_build_array(),
                    'enumerations', jsonb_build_array()
                ),
                created_at
            FROM projects
            """
        )
    )


def downgrade() -> None:
    op.drop_index("ix_change_events_project_id", table_name="change_events")
    op.drop_table("change_events")
    op.drop_index("ix_project_snapshots_project_id", table_name="project_snapshots")
    op.drop_table("project_snapshots")
