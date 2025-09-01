"""
New Database Configuration for PostgreSQL
Clean implementation without legacy SQLite code
"""

import os
from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool

# Database URL from environment or default
def _compose_postgres_url_from_parts() -> str | None:
    host = os.getenv("POSTGRES_HOST") or os.getenv("PGHOST")
    if not host:
        return None
    port = os.getenv("POSTGRES_PORT") or os.getenv("PGPORT") or "5432"
    db = os.getenv("POSTGRES_DB") or os.getenv("PGDATABASE") or "promtok_db"
    user = os.getenv("POSTGRES_USER") or os.getenv("PGUSER") or "promtok_user"
    password = os.getenv("POSTGRES_PASSWORD") or os.getenv("PGPASSWORD") or ""
    auth = f"{user}:{password}" if password else user
    return f"postgresql://{auth}@{host}:{port}/{db}"


def _get_database_url() -> str:
    env_url = os.getenv("DATABASE_URL")
    if env_url:
        return env_url
    composed = _compose_postgres_url_from_parts()
    if composed:
        return composed
    return os.getenv("SQLITE_URL", "sqlite:///./promtok.db")


DATABASE_URL = _get_database_url()

# Create engine with proper pooling for PostgreSQL
engine = create_engine(
    DATABASE_URL,
    poolclass=NullPool,
    echo=False,
    future=True
)

# Session factory
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# Base class for models
Base = declarative_base()


def get_db():
    """
    Dependency to get database session.
    Usage in FastAPI:
        db: Session = Depends(get_db)
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """
    Initialize database tables.
    Note: In production, use Alembic migrations instead.
    """
    from database import models_new
    Base.metadata.create_all(bind=engine)


def test_connection() -> bool:
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


# Export
__all__ = ['engine', 'SessionLocal', 'Base', 'get_db', 'init_db', 'test_connection', 'DATABASE_URL']
