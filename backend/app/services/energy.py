"""Energy and charging-time maths (PRD Algorithms 1).

Charging speed is capped by the vehicle's onboard charger, not the socket:
a scooter draws 0.5-1 kW even on a 3.3 kW point.
"""

CHARGING_EFFICIENCY = 0.9
SOCKET_15A_MAX_KW = 3.3


def energy_needed_kwh(
    current_pct: float, target_pct: float, battery_kwh: float, efficiency: float = CHARGING_EFFICIENCY
) -> float:
    delta = max(0.0, target_pct - current_pct) / 100
    return delta * battery_kwh / efficiency


def socket_kw(connector_type: str, power_kw: float) -> float:
    return min(power_kw, SOCKET_15A_MAX_KW) if connector_type == "15A" else power_kw


def effective_power_kw(charger_kw: float, vehicle_charger_kw: float) -> float:
    return min(charger_kw, vehicle_charger_kw)


def charging_power_kw(connector_type: str, charger_kw: float, vehicle_charger_kw: float | None) -> float:
    """What a vehicle actually draws here: the socket's limit, capped by the vehicle's charger if known."""
    supply = socket_kw(connector_type, charger_kw)
    return supply if vehicle_charger_kw is None else effective_power_kw(supply, vehicle_charger_kw)


def charge_hours(energy_kwh: float, power_kw: float) -> float:
    return energy_kwh / power_kw if power_kw > 0 else float("inf")


def is_compatible(vehicle_connector: str, charger_connector: str) -> bool:
    # Every EV in India ships with a portable charger for a 15A socket.
    return charger_connector == "15A" or vehicle_connector == charger_connector
