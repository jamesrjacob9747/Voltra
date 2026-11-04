from datetime import datetime

MANOJ_LAT, MANOJ_LNG = 12.9352, 77.6245
ARJUN = 5  # seeded driver
MANOJ = 1  # seeded host of CHG001


def _arjun_vehicle(client) -> int:
    return client.get(f"/users/{ARJUN}/vehicles").json()[0]["id"]


def _book(client, charger_id: int, start="2026-11-09T10:05", end="2026-11-09T13:00") -> dict:
    resp = client.post("/bookings", json={"driver_id": ARJUN, "charger_id": charger_id,
                                          "vehicle_id": _arjun_vehicle(client),
                                          "start_time": start, "end_time": end})
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_health_reports_server_time(client):
    assert client.get("/health").json() == {"ok": True, "server_time": "2026-11-09T10:00:00"}


def test_list_chargers_hides_exact_location(client):
    chargers = client.get("/chargers", params={"lat": MANOJ_LAT, "lng": MANOJ_LNG}).json()
    assert len(chargers) == 8
    first = chargers[0]
    assert first["location"]["exact"] is False and first["address"] is None
    assert first["online"] is True and 0 <= first["confidence"]["score"] <= 100


def test_chargematch_returns_ranked_compatible_chargers(client):
    resp = client.post("/match", json={"vehicle_id": _arjun_vehicle(client), "current_pct": 25,
                                       "target_pct": 80, "ready_by": "2026-11-09T17:00",
                                       "lat": MANOJ_LAT, "lng": MANOJ_LNG, "radius_km": 2})
    body = resp.json()
    assert resp.status_code == 200 and body["best"] is not None
    scores = [r["match_score"] for r in body["results"]]
    assert scores == sorted(scores, reverse=True)
    assert all(r["connector_type"] == "15A" for r in body["results"])  # Ather can't use TYPE2
    assert body["best"]["estimate"]["energy_kwh"] == 1.83


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
    assert stopped["bill"] == {"energy_kwh": 1.85, "total_paise": 2220, "platform_fee_paise": 333,
                               "host_share_paise": 1887, "credit_paise": 0, "payable_paise": 2220}

    order = client.post(f"/payments/{booking['id']}/order").json()
    assert order["mode"] == "demo"
    assert client.post(f"/payments/{booking['id']}/demo-pay").json()["status"] == "PAID"

    dash = client.get(f"/host/{MANOJ}/dashboard").json()
    assert dash["today"]["earnings_paise"] == 1887
    assert dash["today"]["energy_sold_kwh"] == 1.85

    review = client.post("/reviews", json={"booking_id": booking["id"], "reviewer_id": ARJUN, "rating": 5})
    assert review.status_code == 201


def test_double_booking_is_rejected(client):
    _book(client, charger_id=1)
    clash = client.post("/bookings", json={"driver_id": ARJUN, "charger_id": 1,
                                           "start_time": "2026-11-09T11:00", "end_time": "2026-11-09T12:00"})
    assert clash.status_code == 409


def test_pending_booking_needs_host_accept(client):
    booking = _book(client, charger_id=7)  # Ejipura host approves manually
    assert booking["status"] == "PENDING"
    host_id = client.get("/chargers/7").json()["host"]["id"]
    accepted = client.patch(f"/bookings/{booking['id']}", json={"action": "accept", "actor_id": host_id})
    assert accepted.json()["status"] == "CONFIRMED"


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
