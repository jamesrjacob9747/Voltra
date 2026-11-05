from datetime import UTC, datetime, timedelta

from app import config
from app.db import rls_statements


def test_database_url_accepts_supabase_and_render_formats():
    want = "postgresql+psycopg://u:p@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres"
    assert (
        config.normalize_database_url("postgresql://u:p@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres") == want
    )
    assert (
        config.normalize_database_url("postgres://u:p@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres") == want
    )
    assert config.normalize_database_url(want) == want
    assert config.normalize_database_url("sqlite:///./voltra.db") == "sqlite:///./voltra.db"


def test_local_now_is_indian_wall_clock_even_on_a_utc_server():
    ist = datetime.now(UTC) + timedelta(hours=5, minutes=30)
    now = config.local_now()
    assert now.tzinfo is None  # stored naive, like every other time in the database
    assert abs((now - ist.replace(tzinfo=None)).total_seconds()) < 5


def test_row_level_security_only_on_postgres():
    assert rls_statements("sqlite") == []
    statements = rls_statements("postgresql")
    assert 'ALTER TABLE "chargers" ENABLE ROW LEVEL SECURITY' in statements
    assert 'ALTER TABLE "device_tokens" ENABLE ROW LEVEL SECURITY' in statements  # push tokens stay private
    assert len(statements) == 9  # every Voltra table
