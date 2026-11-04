from datetime import datetime, timedelta

import pytest

from app.services import energy
from app.services.billing import compute_bill, metered_kwh
from app.services.confidence import compute_confidence
from app.services.match import Candidate, rank
from app.services.pricing import price_at

NOW = datetime(2026, 11, 9, 10, 0)


def test_prd_billing_example():
    kwh = metered_kwh(1542.42, 1544.27)
    bill = compute_bill(kwh, price_per_kwh_paise=1200, fee_bps=1500)
    assert kwh == 1.85
    assert (bill.total_paise, bill.platform_fee_paise, bill.host_share_paise) == (2220, 333, 1887)


def test_bill_parts_always_sum_to_total():
    for kwh in (0.0, 0.001, 0.333, 2.718, 9.999):
        bill = compute_bill(kwh, 1150, 1500)
        assert bill.platform_fee_paise + bill.host_share_paise == bill.total_paise


def test_energy_and_time_for_scooter():
    need = energy.energy_needed_kwh(25, 80, battery_kwh=3.0)
    power = energy.effective_power_kw(energy.socket_kw("15A", 3.3), vehicle_charger_kw=0.75)
    assert need == pytest.approx(1.833, abs=0.001)
    assert power == 0.75  # the scooter's charger is the limit, not the socket
    assert energy.charge_hours(need, power) * 60 == pytest.approx(146.7, abs=0.1)


def test_15a_socket_capped_and_compatibility():
    assert energy.socket_kw("15A", 7.2) == 3.3
    assert energy.socket_kw("TYPE2", 7.2) == 7.2
    assert energy.is_compatible("TYPE2", "15A")
    assert not energy.is_compatible("15A", "TYPE2")


def test_time_of_day_pricing():
    assert price_at(1200, 10) == 1200
    assert price_at(1200, 19) == 1440
    assert price_at(1200, 2) == 960


def _confidence(**overrides):
    args = dict(online=True, host_confirmed=True, total_sessions=143, successful_sessions=140,
                total_bookings=150, host_cancellations=1, last_success_at=NOW - timedelta(days=1),
                slot_free=True, now=NOW)
    return compute_confidence(**{**args, **overrides})


def test_confidence_reliable_charger():
    conf = _confidence()
    assert conf.score == 99
    assert conf.band == "Highly reliable"


def test_confidence_drops_when_offline_and_new_chargers_start_mid():
    assert _confidence(online=False).score == 69
    fresh = _confidence(total_sessions=0, successful_sessions=0, total_bookings=0,
                        host_cancellations=0, last_success_at=None)
    assert fresh.breakdown["successful_sessions"] == 10
    assert fresh.score == 80


def test_confidence_cancellations_floor_at_zero():
    assert _confidence(total_bookings=10, host_cancellations=5).breakdown["cancellation_rate"] == 0


def test_match_prefers_close_reliable_cheap():
    near_good = Candidate(1, distance_km=0.3, availability=1.0, confidence=97, price_paise=1200, power_kw=0.75)
    far_cheap = Candidate(2, distance_km=1.8, availability=1.0, confidence=70, price_paise=900, power_kw=0.75)
    ranked = rank([far_cheap, near_good], radius_km=2.0)
    assert [c.charger_id for c in ranked] == [1, 2]
    assert ranked[0].score > ranked[1].score


def test_match_score_is_out_of_100():
    perfect = Candidate(1, distance_km=0.0, availability=1.0, confidence=100, price_paise=1000, power_kw=3.3)
    assert rank([perfect], radius_km=2.0)[0].score == 100
