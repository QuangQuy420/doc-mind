"""pgvector extension and chunks table

Revision ID: 0001
Revises:
Create Date: 2026-09-03

"""

from collections.abc import Sequence

import pgvector.sqlalchemy
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # The extension is a database-wide object; IF NOT EXISTS keeps the migration
    # re-runnable on a database where someone already enabled it.
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "chunks",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", sa.String(length=255), nullable=False),
        sa.Column("document_id", sa.String(length=255), nullable=False),
        sa.Column("chunk_index", sa.Integer(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("embedding", pgvector.sqlalchemy.Vector(1024), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_chunks_user_id_document_id", "chunks", ["user_id", "document_id"])


def downgrade() -> None:
    op.drop_index("ix_chunks_user_id_document_id", table_name="chunks")
    op.drop_table("chunks")
    # The `vector` extension is deliberately kept: dropping it would break any
    # other table using the type, and re-creating it is free.
