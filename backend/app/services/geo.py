from math import asin, cos, radians, sin, sqrt

EARTH_RADIUS_KM = 6371.0
SCOOTER_CITY_KMH = 20.0


def distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    dlat, dlng = radians(lat2 - lat1), radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return 2 * EARTH_RADIUS_KM * asin(sqrt(a))


def approximate_location(lat: float, lng: float) -> tuple[float, float]:
    # Fixed ~300-400 m offset so the public pin never reveals the exact home (PRD F4).
    return round(lat + 0.0028, 6), round(lng - 0.0021, 6)


def travel_minutes(km: float) -> float:
    return max(5.0, km / SCOOTER_CITY_KMH * 60)
