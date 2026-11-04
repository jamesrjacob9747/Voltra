"""ChargeMatch ranking (PRD Algorithms 2).

Hard filters (radius, connector, free slot, finishes by ready-by) are applied by the
caller; this module scores the survivors 0-100 from factors normalised to 0-1.
"""
from dataclasses import dataclass

WEIGHTS = {"distance": 30, "availability": 25, "reliability": 20, "price": 15, "power": 10}


@dataclass
class Candidate:
    charger_id: int
    distance_km: float
    availability: float  # share of the search window that is free, 0-1
    confidence: int  # 0-100
    price_paise: int
    power_kw: float  # effective kW for this vehicle
    score: float = 0.0


def rank(candidates: list[Candidate], radius_km: float) -> list[Candidate]:
    if not candidates:
        return []
    prices = [c.price_paise for c in candidates]
    lo, hi = min(prices), max(prices)
    top_power = max(c.power_kw for c in candidates) or 1.0

    for c in candidates:
        factors = {
            "distance": max(0.0, 1 - c.distance_km / radius_km),
            "availability": c.availability,
            "reliability": c.confidence / 100,
            "price": 1.0 if hi == lo else (hi - c.price_paise) / (hi - lo),
            "power": c.power_kw / top_power,
        }
        c.score = round(sum(WEIGHTS[k] * v for k, v in factors.items()), 1)
    return sorted(candidates, key=lambda c: c.score, reverse=True)
