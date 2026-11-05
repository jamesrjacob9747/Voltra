"""Push notifications through Firebase Cloud Messaging (HTTP v1 API).

Routers queue `notify(...)` as a FastAPI background task, so it runs after the response is sent and a
slow or failing push never delays or breaks a booking. Without a Firebase service account (tests, a
laptop without Firebase) every call is a no-op.
"""

import json
import logging
import os
from dataclasses import dataclass, field
from datetime import datetime

import httpx
from sqlalchemy import delete, select

from ..config import settings
from ..db import SessionLocal
from ..models import DeviceToken, User

log = logging.getLogger("voltra.push")

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


@dataclass(frozen=True)
class Message:
    token: str
    title: str
    body: str
    data: dict[str, str] = field(default_factory=dict)


class FcmSender:
    def __init__(self, service_account: dict):
        from google.oauth2 import service_account as sa

        self.project_id = service_account["project_id"]
        self._creds = sa.Credentials.from_service_account_info(service_account, scopes=[FCM_SCOPE])

    def _access_token(self) -> str:
        from google.auth.transport.requests import Request

        if not self._creds.valid:  # cached for about an hour
            self._creds.refresh(Request())
        return self._creds.token

    def send(self, m: Message) -> bool:
        """Returns False when FCM reports the token dead (app uninstalled or its data cleared)."""
        resp = httpx.post(
            f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send",
            headers={"Authorization": f"Bearer {self._access_token()}"},
            json={
                "message": {
                    "token": m.token,
                    "notification": {"title": m.title, "body": m.body},
                    "data": m.data,
                    "android": {"priority": "high"},
                }
            },
            timeout=10,
        )
        if resp.status_code == 404 or (resp.status_code == 400 and "registration token" in resp.text):
            return False
        resp.raise_for_status()
        return True


_sender: FcmSender | None | bool = None  # None: not loaded yet; False: push is off. Tests replace it.


def sender() -> FcmSender | None:
    global _sender
    if _sender is None:
        path = settings.firebase_service_account_file
        if path and os.path.isfile(path):
            with open(path, encoding="utf-8") as f:
                _sender = FcmSender(json.load(f))
            log.info("Push notifications on (Firebase project %s)", _sender.project_id)
        else:
            _sender = False
    return _sender or None


def notify(user_id: int, title: str, body: str, **data: str) -> None:
    """Sends to every device the user has signed in on. The title starts with the user's name, because
    on a demo phone several seeded users share one device."""
    s = sender()
    if s is None:
        return
    with SessionLocal() as db:
        name = db.scalar(select(User.name).where(User.id == user_id))
        tokens = list(db.scalars(select(DeviceToken.token).where(DeviceToken.user_id == user_id)))
        dead = []
        for token in tokens:
            try:
                if not s.send(Message(token, f"{name}: {title}", body, {**data, "user_id": str(user_id)})):
                    dead.append(token)
            except Exception:  # noqa: BLE001  (a push must never take the server down)
                log.warning("Push to user %s failed", user_id, exc_info=True)
        if dead:
            db.execute(delete(DeviceToken).where(DeviceToken.user_id == user_id, DeviceToken.token.in_(dead)))
            db.commit()


def clock_time(t: datetime) -> str:
    """21:40 -> "9:40 PM" (strftime's no-padding flags differ between Windows and Linux)."""
    return t.strftime("%I:%M %p").lstrip("0")


def slot(start: datetime, end: datetime) -> str:
    return f"{clock_time(start)}–{clock_time(end)}"


def rupees(paise: int) -> str:
    return f"₹{paise / 100:.2f}"
