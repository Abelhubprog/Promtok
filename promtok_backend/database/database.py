from sqlalchemy import create_engine, pool, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
import logging

logger = logging.getLogger(__name__)


def _compose_postgres_url_from_parts() -> str | None:
    """Build a PostgreSQL URL from discrete env vars if present.

    Considers POSTGRES_* and PG* variables commonly set in PaaS.
    Returns None if required host is not provided.
    """
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
    """Determine the database URL with safe fallbacks.

    Priority:
    1) DATABASE_URL
    2) Compose from POSTGRES_*/PG* parts
    3) Fallback to SQLite for local/dev (sqlite:///./promtok.db)
    """
    env_url = os.getenv("DATABASE_URL")
    if env_url:
        return env_url

    composed = _compose_postgres_url_from_parts()
    if composed:
        return composed

    # Final fallback for local development to avoid unresolved host 'postgres'
    fallback_sqlite = os.getenv("SQLITE_URL", "sqlite:///./promtok.db")
    logger.warning(
        "DATABASE_URL not set; falling back to SQLite at %s (not recommended for production)",
        fallback_sqlite,
    )
    return fallback_sqlite


# Resolve DATABASE_URL once at import
DATABASE_URL = _get_database_url()

# Configure engine based on URL scheme
if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        echo=False,
        future=True,
    )
else:
    engine = create_engine(
        DATABASE_URL,
        pool_size=20,
        max_overflow=10,
        pool_pre_ping=True,
        pool_recycle=3600,
        echo=False,
        future=True,
        connect_args={
            "connect_timeout": 10,
            "options": "-c statement_timeout=30000",
        },
    )
    try:
        host_info = DATABASE_URL.split("@", 1)[1].split("/", 1)[0]
        logger.info(f"Connected to PostgreSQL database host: {host_info}")
    except Exception:
        logger.info("Connected to PostgreSQL database")


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """Dependency to get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Initialize database tables"""
    try:
        # Import all models to ensure they're registered with Base
        from . import models

        # Create all tables
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {str(e)}")
        raise


def test_connection():
    """Test database connection"""
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            result.fetchone()
        logger.info("Database connection test successful")
        return True
    except Exception as e:
        logger.error(f"Database connection test failed: {str(e)}")
        return False
