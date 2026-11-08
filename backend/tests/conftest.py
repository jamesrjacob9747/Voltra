import os
import tempfile
from datetime import datetime, timedelta

# Point the app at a throwaway SQLite file, and blank anything a developer's backend/.env might
# set (Supabase, Razorpay keys, Firebase key), before the app is imported. load_dotenv() never
# overrides variables that are already set.
os.environ["DATABASE_URL"] = "sqlite:///" + os.path.join(tempfile.gettempdir(), "voltra_test.db")
for name in ("RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "FIREBASE_SERVICE_ACCOUNT_FILE"):
    os.environ[name] = ""
os.environ["DEMO_ENDPOINTS"] = "true"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402
from app.seed import reset_and_seed  # noqa: E402
from app.services import plug  # noqa: E402


class FakeClock:
    def __init__(self, start: datetime):
        self.now = start

    def __call__(self) -> datetime:
        return self.now

    def advance(self, **kwargs) -> None:
        self.now += timedelta(**kwargs)


@pytest.fixture
def clock(monkeypatch):
    # 10:00 on a fixed day: outside peak and off-peak pricing.
    fake = FakeClock(datetime(2026, 11, 9, 10, 0))
    monkeypatch.setattr(plug, "clock", fake)
    monkeypatch.setattr(plug, "demo_speed", 1.0)
    return fake


@pytest.fixture
def client(clock):
    plug.reset_plugs()
    reset_and_seed()
    with TestClient(app) as c:
        yield c
