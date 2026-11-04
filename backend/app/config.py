import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./voltra.db")
    plug_mode: str = os.getenv("PLUG_MODE", "simulated")
    demo_speed: float = float(os.getenv("DEMO_SPEED", "30"))
    platform_fee_bps: int = int(os.getenv("PLATFORM_FEE_BPS", "1500"))
    chargesure_credit_paise: int = int(os.getenv("CHARGESURE_CREDIT_PAISE", "2000"))
    heartbeat_timeout_s: int = int(os.getenv("HEARTBEAT_TIMEOUT_S", "30"))
    razorpay_key_id: str = os.getenv("RAZORPAY_KEY_ID", "")
    razorpay_key_secret: str = os.getenv("RAZORPAY_KEY_SECRET", "")
    # Unauthenticated stage controls (/admin/*, demo payment). Turn off outside the demo.
    demo_endpoints: bool = os.getenv("DEMO_ENDPOINTS", "true").lower() == "true"


settings = Settings()
