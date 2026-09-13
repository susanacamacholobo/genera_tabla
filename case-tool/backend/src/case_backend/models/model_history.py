from datetime import datetime
from typing import Any

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from case_backend.database import Base
from case_backend.models.project import utc_now

json_type = JSON().with_variant(JSONB(), "postgresql")


class ProjectSnapshotRecord(Base):
    __tablename__ = "project_snapshots"
    __table_args__ = (
        UniqueConstraint("project_id", "revision", name="uq_project_snapshots_revision"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    project_id: Mapped[str] = mapped_column(
        ForeignKey("projects.id", ondelete="CASCADE"), nullable=False, index=True
    )
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    model_json: Mapped[dict[str, Any]] = mapped_column(json_type, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)


class ChangeEventRecord(Base):
    __tablename__ = "change_events"
    __table_args__ = (
        UniqueConstraint("project_id", "revision", name="uq_change_events_revision"),
        UniqueConstraint("project_id", "command_id", name="uq_change_events_command"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    project_id: Mapped[str] = mapped_column(
        ForeignKey("projects.id", ondelete="CASCADE"), nullable=False, index=True
    )
    command_id: Mapped[str] = mapped_column(String(200), nullable=False)
    base_revision: Mapped[int] = mapped_column(Integer, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    command_json: Mapped[dict[str, Any]] = mapped_column(json_type, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
