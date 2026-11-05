import hashlib
import hmac
from dataclasses import replace
from datetime import datetime

import httpx
import pytest

from app.routers import admin, payments

MANOJ_LAT, MANOJ_LNG = 12.9352, 77.6245
ARJUN = 5  # seeded driver
MANOJ = 1  # seeded host of CHG001


def _arjun_vehicle(client) -> int:
    return client.get(f"/users/{ARJUN}/vehicles").json()[0]["id"]


def _book(client, charger_id: int, start="2026-11-09T10:05", end="2026-11-09T13:00") -> dict:
    resp = client.post(
        "/bookings",
        json={
            "driver_id": ARJUN,
            "charger_id": charger_id,
            "vehicle_id": _arjun_vehicle(client),
            "start_time": start,
            "end_time": end,
        },
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_demo_endpoints_can_be_switched_off(client, monkeypatch):
    assert client.post("/admin/plugs/CHG001/online", json={"online": True}).status_code == 200
    monkeypatch.setattr(admin, "settings", replace(admin.settings, demo_endpoints=False))
    assert client.post("/admin/plugs/CHG001/online", json={"online": True}).status_code == 404
    assert client.post("/admin/reset").status_code == 404
    assert client.post("/payments/1/demo-pay").status_code == 404


def test_admin_token_required_when_set(client, monkeypatch):
    monkeypatch.setattr(admin, "settings", replace(admin.settings, admin_token="s3cret-token"))
    url, body = "/admin/plugs/CHG001/online", {"online": True}
    assert client.post(url, json=body).status_code == 403
    assert client.post(url, json=body, headers={"X-Admin-Token": "wrong"}).status_code == 403
    assert client.post(url, json=body, headers={"X-Admin-Token": "s3cret-token"}).status_code == 200
    assert client.post("/payments/1/demo-pay").status_code == 403  # demo payment is guarded too


def test_razorpay_verify_refuses_without_keys(client):
    resp = client.post(
        "/payments/verify",
        json={"booking_id": 1, "razorpay_order_id": "x", "razorpay_payment_id": "y", "razorpay_signature": "z"},
    )
    assert resp.status_code == 409


def test_health_reports_server_time(client):
    assert client.get("/health").json() == {"ok": True, "server_time": "2026-11-09T10:00:00"}


def test_list_chargers_hides_exact_location(client):
    chargers = client.get("/chargers", params={"lat": MANOJ_LAT, "lng": MANOJ_LNG}).json()
    assert len(chargers) == 8
    first = chargers[0]
    assert first["location"]["exact"] is False and first["address"] is None
    assert first["online"] is True and 0 <= first["confidence"]["score"] <= 100


def test_chargematch_returns_ranked_compatible_chargers(client):
    resp = client.post(
        "/match",
        json={
            "vehicle_id": _arjun_vehicle(client),
            "current_pct": 25,
            "target_pct": 80,
            "ready_by": "2026-11-09T17:00",
            "lat": MANOJ_LAT,
            "lng": MANOJ_LNG,
            "radius_km": 2,
        },
    )
    body = resp.json()
    assert resp.status_code == 200 and body["best"] is not None
    scores = [r["match_score"] for r in body["results"]]
    assert scores == sorted(scores, reverse=True)
    assert all(r["connector_type"] == "15A" for r in body["results"])  # Ather can't use TYPE2
    assert body["best"]["estimate"]["energy_kwh"] == 1.83
    # Daytime, ready by 5 PM: everything is normal price, so there is no cheaper later slot.
    assert all(r["estimate"]["cheaper_later"] is None for r in body["results"])


def _match_manoj(client, ready_by: str) -> dict:
    body = client.post(
        "/match",
        json={
            "vehicle_id": _arjun_vehicle(client),
            "current_pct": 25,
            "target_pct": 80,
            "ready_by": ready_by,
            "lat": MANOJ_LAT,
            "lng": MANOJ_LNG,
            "radius_km": 2,
        },
    ).json()
    return next(r for r in body["results"] if r["id"] == 1)  # Manoj's charger, ₹12 base


def test_evening_search_offers_cheaper_off_peak_slot(client, clock):
    clock.now = datetime(2026, 11, 9, 19, 0)  # evening peak: ₹12 → ₹14.40
    manoj = _match_manoj(client, ready_by="07:00")  # tomorrow morning
    est = manoj["estimate"]
    later = est["cheaper_later"]
    assert later is not None
    # Earliest off-peak start (₹9.60) that finishes by 7 AM: midnight, done 146.7 min later.
    assert later["start_at"] == "2026-11-10T00:00"
    assert later["finish_at"] == "2026-11-10T02:26"  # 02:26:40, shown to the minute
    assert later["price_per_kwh_paise"] == 960
    assert later["saving_paise"] == est["est_cost_paise"] - later["est_cost_paise"]
    assert later["saving_paise"] > 800  # about a third off for 1.83 kWh

    # Reserving the suggested slot works, and starting it at midnight locks the off-peak price.
    booking = _book(client, charger_id=1, start=later["start_at"], end=later["finish_at"])
    clock.now = datetime(2026, 11, 10, 0, 0)
    start = client.post("/sessions/start", json={"booking_id": booking["id"], "qr": "voltra://charger/CHG001"})
    assert start.json()["price_per_kwh_paise"] == 960


def test_cheaper_slot_is_not_offered_when_already_booked(client, clock):
    clock.now = datetime(2026, 11, 9, 19, 0)
    # Priya holds Manoj's charger for the whole off-peak window.
    taken = client.post(
        "/bookings",
        json={
            "driver_id": 4,
            "charger_id": 1,
            "start_time": "2026-11-10T00:00",
            "end_time": "2026-11-10T06:00",
        },
    )
    assert taken.status_code == 201
    # Normal-price evening slots would run past midnight, so nothing cheaper is free.
    assert _match_manoj(client, ready_by="07:00")["estimate"]["cheaper_later"] is None


def test_full_journey_bills_from_the_meter(client, clock):
    booking = _book(client, charger_id=1)
    assert booking["status"] == "CONFIRMED"  # Manoj auto-approves

    # Exact address unlocks once the booking is confirmed.
    assert client.get("/chargers/1", params={"user_id": ARJUN}).json()["location"]["exact"] is True

    wrong = client.post("/sessions/start", json={"booking_id": booking["id"], "qr": "voltra://charger/CHG002"})
    assert wrong.status_code == 409

    assert booking["session_id"] is None
    start = client.post("/sessions/start", json={"booking_id": booking["id"], "qr": "voltra://charger/CHG001"})
    assert start.status_code == 201, start.text
    session_id = start.json()["session_id"]
    assert client.get(f"/bookings/{booking['id']}").json()["session_id"] == session_id

    # Ather draws 0.75 kW; 148 minutes = 1.85 kWh.
    clock.advance(minutes=148)
    live = client.get(f"/sessions/{session_id}/live").json()
    assert live["energy_kwh"] == 1.85 and live["power_kw"] == 0.75
    assert live["duration_s"] == 148 * 60  # demo_speed is 1 in tests

    stopped = client.post(f"/sessions/{session_id}/stop").json()
    assert stopped["bill"] == {
        "energy_kwh": 1.85,
        "total_paise": 2220,
        "platform_fee_paise": 333,
        "host_share_paise": 1887,
        "credit_paise": 0,
        "payable_paise": 2220,
    }

    order = client.post(f"/payments/{booking['id']}/order").json()
    assert order["mode"] == "demo"
    assert client.post(f"/payments/{booking['id']}/demo-pay").json()["status"] == "PAID"

    dash = client.get(f"/host/{MANOJ}/dashboard").json()
    assert dash["today"]["earnings_paise"] == 1887
    assert dash["today"]["energy_sold_kwh"] == 1.85

    review = client.post("/reviews", json={"booking_id": booking["id"], "reviewer_id": ARJUN, "rating": 5})
    assert review.status_code == 201


TEST_KEY_ID, TEST_SECRET = "rzp_test_fake", "fake-secret"


def _billed_booking(client, clock) -> int:
    booking = _book(client, charger_id=1)
    start = client.post("/sessions/start", json={"booking_id": booking["id"], "qr": "voltra://charger/CHG001"})
    clock.advance(minutes=148)
    client.post(f"/sessions/{start.json()['session_id']}/stop")
    return booking["id"]


@pytest.fixture
def razorpay(monkeypatch):
    """Razorpay test keys on the server, and a fake Orders API that records what it was sent."""
    monkeypatch.setattr(
        payments, "settings", replace(payments.settings, razorpay_key_id=TEST_KEY_ID, razorpay_key_secret=TEST_SECRET)
    )
    calls = []

    def fake_post(url, *, auth, json, timeout):
        calls.append({"url": url, "auth": auth, "json": json})
        return httpx.Response(
            200, json={"id": f"order_fake{len(calls)}", "amount": json["amount"], "status": "created"}
        )

    monkeypatch.setattr(payments.httpx, "post", fake_post)
    return calls


def _sign(order_id: str, payment_id: str, secret: str = TEST_SECRET) -> str:
    return hmac.new(secret.encode(), f"{order_id}|{payment_id}".encode(), hashlib.sha256).hexdigest()


def test_razorpay_order_and_verified_payment(client, clock, razorpay):
    booking_id = _billed_booking(client, clock)

    order = client.post(f"/payments/{booking_id}/order").json()
    assert order["mode"] == "razorpay" and order["key_id"] == TEST_KEY_ID
    assert order["razorpay_order_id"] == "order_fake1" and order["payable_paise"] == 2220
    assert razorpay[0]["json"]["amount"] == 2220 and razorpay[0]["json"]["currency"] == "INR"
    assert razorpay[0]["auth"] == (TEST_KEY_ID, TEST_SECRET)

    # Closing the checkout and tapping Pay again reuses the order.
    assert client.post(f"/payments/{booking_id}/order").json()["razorpay_order_id"] == "order_fake1"
    assert len(razorpay) == 1

    body = {"booking_id": booking_id, "razorpay_order_id": "order_fake1", "razorpay_payment_id": "pay_fake1"}
    forged = client.post(
        "/payments/verify", json={**body, "razorpay_signature": _sign("order_fake1", "pay_fake1", "wrong")}
    )
    assert forged.status_code == 400
    assert client.get(f"/payments/{booking_id}").json()["status"] == "PENDING"

    good = {**body, "razorpay_signature": _sign("order_fake1", "pay_fake1")}
    assert client.post("/payments/verify", json=good).json()["status"] == "PAID"
    assert client.post("/payments/verify", json=good).json()["status"] == "PAID"  # a retry is harmless
    assert client.get(f"/host/{MANOJ}/dashboard").json()["today"]["earnings_paise"] == 1887
    assert client.post(f"/payments/{booking_id}/order").status_code == 409


def test_razorpay_verify_rejects_another_bookings_order(client, clock, razorpay):
    booking_id = _billed_booking(client, clock)
    client.post(f"/payments/{booking_id}/order")
    body = {"booking_id": booking_id, "razorpay_order_id": "order_other", "razorpay_payment_id": "pay_x"}
    resp = client.post("/payments/verify", json={**body, "razorpay_signature": _sign("order_other", "pay_x")})
    assert resp.status_code == 409


def test_razorpay_outage_is_reported_not_crashed(client, clock, razorpay, monkeypatch):
    booking_id = _billed_booking(client, clock)

    def down(*args, **kwargs):
        raise httpx.ConnectError("no route")

    monkeypatch.setattr(payments.httpx, "post", down)
    resp = client.post(f"/payments/{booking_id}/order")
    assert resp.status_code == 502 and "Razorpay" in resp.json()["detail"]


def test_double_booking_is_rejected(client):
    _book(client, charger_id=1)
    clash = client.post(
        "/bookings",
        json={"driver_id": ARJUN, "charger_id": 1, "start_time": "2026-11-09T11:00", "end_time": "2026-11-09T12:00"},
    )
    assert clash.status_code == 409


def test_pending_booking_needs_host_accept(client):
    booking = _book(client, charger_id=7)  # Ejipura host approves manually
    assert booking["status"] == "PENDING"
    host_id = client.get("/chargers/7").json()["host"]["id"]
    accepted = client.patch(f"/bookings/{booking['id']}", json={"action": "accept", "actor_id": host_id})
    assert accepted.json()["status"] == "CONFIRMED"


def test_host_dashboard_counts_only_todays_live_bookings(client):
    arrived = _book(client, charger_id=1)
    client.patch(f"/bookings/{arrived['id']}", json={"action": "arrive", "actor_id": ARJUN})
    cancelled = _book(client, charger_id=1, start="2026-11-09T14:00", end="2026-11-09T15:00")
    client.patch(f"/bookings/{cancelled['id']}", json={"action": "cancel", "actor_id": ARJUN})
    _book(client, charger_id=1, start="2026-11-10T10:00", end="2026-11-10T11:00")  # tomorrow

    dash = client.get(f"/host/{MANOJ}/dashboard").json()
    assert dash["today"]["bookings"] == 1
    assert [b["id"] for b in dash["upcoming"]][0] == arrived["id"]  # arrived drivers stay visible


NEW_CHARGER = {
    "host_id": MANOJ,
    "name": "Manoj's Office Socket",
    "lat": 12.9340,
    "lng": 77.6260,
    "address": "3rd Floor, 80 Feet Road, Koramangala",
    "connector_type": "15A",
    "power_kw": 3.3,
    "base_price_per_kwh_paise": 1300,
    "available_from": "08:00",
    "available_to": "20:00",
    "auto_approve": True,
}


def test_host_adds_a_charger_that_drivers_can_book_and_start(client, clock):
    resp = client.post("/chargers", json=NEW_CHARGER)
    assert resp.status_code == 201, resp.text
    charger = resp.json()
    assert charger["device_id"] == "CHG009"  # next after the 8 seeded chargers
    assert charger["verified"] is False and charger["location"]["exact"] is True

    mine = client.get(f"/host/{MANOJ}/chargers").json()
    assert [c["device_id"] for c in mine] == ["CHG001", "CHG007", "CHG009"]
    public = client.get("/chargers", params={"lat": 12.9340, "lng": 77.6260}).json()
    listed = next(c for c in public if c["id"] == charger["id"])
    assert listed["location"]["exact"] is False  # the public pin stays approximate

    booking = _book(client, charger_id=charger["id"])
    start = client.post("/sessions/start", json={"booking_id": booking["id"], "qr": "voltra://charger/CHG009"})
    assert start.status_code == 201, start.text


def test_only_hosts_can_add_chargers(client):
    assert client.post("/chargers", json={**NEW_CHARGER, "host_id": ARJUN}).status_code == 403
    assert client.post("/chargers", json={**NEW_CHARGER, "host_id": 999}).status_code == 404


def test_add_charger_rejects_bad_input(client):
    bad = [
        {"base_price_per_kwh_paise": 0},
        {"power_kw": 0},
        {"available_from": "20:00", "available_to": "08:00"},
        {"available_to": "24:00"},
        {"lat": 0.0, "lng": 0.0},
        {"name": "A"},
    ]
    for override in bad:
        assert client.post("/chargers", json={**NEW_CHARGER, **override}).status_code == 422, override


def test_impact_from_the_seeded_track_record(client):
    imp = client.get("/impact").json()
    # 8 seeded chargers from 4 hosts, with 391 successful sessions between them.
    assert (imp["chargers"], imp["verified_chargers"], imp["hosts"]) == (8, 8, 4)
    assert imp["sessions_completed"] == 391 and imp["estimated_sessions"] == 391
    assert imp["kwh_shared"] == 703.8  # 391 × 1.8 kWh estimate
    assert imp["petrol_litres_avoided"] == 422.3  # 30 km/kWh ÷ 50 km/L = 0.6 L per kWh
    assert imp["co2_kg_avoided"] == 468.7  # petrol CO₂ minus grid CO₂ for the same kWh
    assert imp["chargesure_rescues"] == 0
    assert imp["factors"]["grid_co2_kg_per_kwh"] == 0.72


def test_impact_adds_real_metered_sessions_and_rescues(client, clock):
    booking = _book(client, charger_id=1)
    session = client.post("/sessions/start", json={"booking_id": booking["id"], "qr": "voltra://charger/CHG001"})
    clock.advance(minutes=148)  # 1.85 kWh at the Ather's 0.75 kW
    client.post(f"/sessions/{session.json()['session_id']}/stop")

    imp = client.get("/impact").json()
    assert imp["sessions_completed"] == 392
    assert imp["estimated_sessions"] == 391  # the real one is metered, not estimated
    assert imp["kwh_shared"] == round(1.85 + 391 * 1.8, 1)

    moved = _book(client, charger_id=1, start="2026-11-09T14:00", end="2026-11-09T15:00")
    client.post("/admin/plugs/CHG001/online", json={"online": False})
    client.post(f"/bookings/{moved['id']}/transfer", json={"to_charger_id": 2})
    assert client.get("/impact").json()["chargesure_rescues"] == 1


def test_chargesure_moves_booking_when_charger_goes_offline(client):
    booking = _book(client, charger_id=1)
    client.post("/admin/plugs/CHG001/online", json={"online": False})

    health = client.get(f"/bookings/{booking['id']}/health").json()
    assert health["online"] is False and health["credit_paise"] == 2000
    alt_ids = [a["id"] for a in health["alternatives"]]
    assert 2 in alt_ids  # Rahul's charger, ~350 m away

    failed = client.post("/sessions/start", json={"booking_id": booking["id"], "qr": "voltra://charger/CHG001"})
    assert failed.status_code == 409 and failed.json()["detail"]["code"] == "CHARGER_OFFLINE"

    moved = client.post(f"/bookings/{booking['id']}/transfer", json={"to_charger_id": 2})
    assert moved.status_code == 201
    new = moved.json()
    assert new["status"] == "CONFIRMED" and new["credit_paise"] == 2000
    assert client.get(f"/bookings/{booking['id']}").json()["status"] == "CANCELLED"

    started = client.post("/sessions/start", json={"booking_id": new["id"], "qr": "voltra://charger/CHG002"})
    assert started.status_code == 201
