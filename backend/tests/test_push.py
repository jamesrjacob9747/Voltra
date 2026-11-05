import pytest

from app.services import push

ARJUN, MANOJ, PRIYA = 5, 1, 4
ARJUN_PHONE, MANOJ_PHONE = "arjun-token-" + "a" * 20, "manoj-token-" + "m" * 20


class FakeFcm:
    def __init__(self):
        self.sent: list[push.Message] = []
        self.dead: set[str] = set()

    def send(self, m: push.Message) -> bool:
        if m.token in self.dead:
            return False
        self.sent.append(m)
        return True

    def to(self, token: str) -> list[str]:
        return [f"{m.title} | {m.body}" for m in self.sent if m.token == token]


@pytest.fixture
def fcm(client, monkeypatch):
    fake = FakeFcm()
    monkeypatch.setattr(push, "_sender", fake)
    for user, token in ((ARJUN, ARJUN_PHONE), (MANOJ, MANOJ_PHONE)):
        assert client.post(f"/users/{user}/device-token", json={"token": token}).status_code == 204
    return fake


def _book(client, charger_id=1, start="2026-11-09T10:05", end="2026-11-09T13:00"):
    body = {"driver_id": ARJUN, "charger_id": charger_id, "vehicle_id": 1, "start_time": start, "end_time": end}
    resp = client.post("/bookings", json=body)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_registering_the_same_token_twice_keeps_one(client, fcm):
    assert client.post(f"/users/{ARJUN}/device-token", json={"token": ARJUN_PHONE}).status_code == 204
    _book(client)
    assert fcm.to(ARJUN_PHONE) == []  # the booking went to the host, not the driver
    assert len(fcm.to(MANOJ_PHONE)) == 1


def test_unknown_user_or_bad_token_is_rejected(client):
    assert client.post("/users/999/device-token", json={"token": ARJUN_PHONE}).status_code == 404
    assert client.post(f"/users/{ARJUN}/device-token", json={"token": "short"}).status_code == 422


def test_full_journey_notifies_host_and_driver(client, clock, fcm):
    booking = _book(client)
    assert fcm.to(MANOJ_PHONE) == ["Manoj: New booking | Arjun booked Manoj's Home Charger, 10:05 AM–1:00 PM."]
    assert fcm.sent[0].data == {"type": "booking", "booking_id": str(booking["id"]), "user_id": str(MANOJ)}

    start = client.post("/sessions/start", json={"booking_id": booking["id"], "qr": "voltra://charger/CHG001"})
    clock.advance(minutes=148)
    client.post(f"/sessions/{start.json()['session_id']}/stop")
    assert fcm.to(ARJUN_PHONE) == ["Arjun: Charging complete | 1.85 kWh at Manoj's Home Charger. ₹22.20 to pay."]

    client.post(f"/payments/{booking['id']}/demo-pay")
    assert fcm.to(MANOJ_PHONE)[-1] == (
        "Manoj: Payment received | You earned ₹18.87 from Arjun's charge at Manoj's Home Charger."
    )


def test_request_to_book_and_host_decision(client, fcm):
    client.post(f"/users/{PRIYA}/device-token", json={"token": "priya-token-" + "p" * 20})
    booking = _book(client, charger_id=4)  # Priya's Wallbox needs the host to approve
    assert fcm.sent[-1].title == "Priya: New booking request"
    assert "Open Voltra to accept" in fcm.sent[-1].body

    client.patch(f"/bookings/{booking['id']}", json={"action": "decline", "actor_id": PRIYA})
    assert fcm.to(ARJUN_PHONE)[-1].startswith("Arjun: Booking declined | Priya's Wallbox can't take")


def test_charger_going_offline_warns_drivers_with_upcoming_bookings(client, fcm):
    _book(client)
    client.post("/admin/plugs/CHG001/online", json={"online": False})
    assert fcm.to(ARJUN_PHONE) == [
        "Arjun: Your charger is offline | Manoj's Home Charger just went offline. "
        "Open Voltra: ChargeSure has nearby chargers and a ₹20.00 credit."
    ]
    client.post("/admin/plugs/CHG001/online", json={"online": True})  # back online: no extra push
    assert len(fcm.to(ARJUN_PHONE)) == 1


def test_dead_tokens_are_removed_and_failures_never_break_requests(client, fcm, monkeypatch):
    fcm.dead.add(MANOJ_PHONE)
    _book(client)
    _book(client, start="2026-11-09T14:00", end="2026-11-09T15:00")
    assert fcm.to(MANOJ_PHONE) == []

    def broken(m):
        raise RuntimeError("FCM is down")

    monkeypatch.setattr(fcm, "send", broken)
    assert client.post(f"/users/{MANOJ}/device-token", json={"token": MANOJ_PHONE}).status_code == 204
    _book(client, start="2026-11-09T16:00", end="2026-11-09T17:00")  # still 201


def test_push_is_off_without_a_service_account(client, monkeypatch):
    monkeypatch.setattr(push, "_sender", None)
    monkeypatch.setattr(push, "settings", push.settings.__class__(firebase_service_account_file="no-such-file.json"))
    assert push.sender() is None
    _book(client)  # no error, nothing sent
