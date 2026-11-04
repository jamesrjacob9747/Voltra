from sqlalchemy import create_engine, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import settings


class Base(DeclarativeBase):
    pass


def make_engine(url: str):
    if url.startswith("sqlite"):
        return create_engine(url, connect_args={"check_same_thread": False})
    # Hosted Postgres (Supabase pooler): drop dead connections quietly instead of failing a request.
    return create_engine(url, pool_pre_ping=True, pool_recycle=300)


engine = make_engine(settings.database_url)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def rls_statements(dialect: str) -> list[str]:
    """Supabase also exposes every public table over its REST API. Row level security with no
    policies closes that door; our server's direct connection (table owner) is unaffected."""
    if dialect != "postgresql":
        return []
    return [f'ALTER TABLE "{t.name}" ENABLE ROW LEVEL SECURITY' for t in Base.metadata.sorted_tables]


def create_schema() -> None:
    from . import models  # noqa: F401  (registers the tables on Base.metadata)

    Base.metadata.create_all(engine)
    statements = rls_statements(engine.dialect.name)
    if statements:
        with engine.begin() as conn:
            for statement in statements:
                conn.execute(text(statement))


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
