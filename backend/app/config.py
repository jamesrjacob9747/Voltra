import os
from dataclasses import dataclass, field
from datetime import datetime
from zoneinfo import ZoneInfo

from dotenv import load_dotenv

load_dotenv()


def normalize_database_url(url: str) -> str:
    """Accept Postgres URLs exactly as Supabase/Render show them; SQLAlchemy needs the psycopg driver named."""
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return "postgresql+psycopg://" + url[len(prefix) :]
    return url


@dataclass(frozen=True)
class Settings:
    database_url: str = field(
        default_factory=lambda: normalize_database_url(os.getenv("DATABASE_URL", "sqlite:///./voltra.db"))
    )
    plug_mode: str = os.getenv("PLUG_MODE", "simulated")
    demo_speed: float = float(os.getenv("DEMO_SPEED", "30"))
    platform_fee_bps: int = int(os.getenv("PLATFORM_FEE_BPS", "1500"))
    chargesure_credit_paise: int = int(os.getenv("CHARGESURE_CREDIT_PAISE", "2000"))
    heartbeat_timeout_s: int = int(os.getenv("HEARTBEAT_TIMEOUT_S", "30"))
    razorpay_key_id: str = os.getenv("RAZORPAY_KEY_ID", "")
    razorpay_key_secret: str = os.getenv("RAZORPAY_KEY_SECRET", "")
    # Unauthenticated stage controls (/admin/*, demo payment). Turn off outside the demo.
    demo_endpoints: bool = os.getenv("DEMO_ENDPOINTS", "true").lower() == "true"
    # Bookings, "today" and peak pricing are wall-clock times in this zone, wherever the server runs.
    timezone: str = os.getenv("TIMEZONE", "Asia/Kolkata")
    # Firebase service-account key (JSON file) for push notifications; push is off when the file is missing.
    # On Render, upload it as a Secret File and point this at /etc/secrets/<name>.
    firebase_service_account_file: str = os.getenv("FIREBASE_SERVICE_ACCOUNT_FILE", "firebase-service-account.json")


settings = Settings()


def local_now() -> datetime:
    """Current wall-clock time in settings.timezone, stored naive like every other time in the database."""
    return datetime.now(ZoneInfo(settings.timezone)).replace(tzinfo=None)
