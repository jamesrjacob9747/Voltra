"""Smart plug drivers behind one interface: read() and switch(on).

Only SimulatedPlug exists for now. A ShellyPlug(ip) using the plug's local HTTP API
(/rpc/Switch.GetStatus, /rpc/Switch.Set) slots in later via PLUG_MODE=shelly.
"""
from dataclasses import dataclass
from datetime import datetime

from ..config import settings

NOMINAL_VOLTAGE = 230.0

# Swappable for tests.
clock = datetime.now
demo_speed = settings.demo_speed


@dataclass(frozen=True)
class PlugReading:
    on: bool
    voltage: float
    current: float
    power_w: float
    energy_kwh: float  # cumulative meter


class SimulatedPlug:
    def __init__(self, device_id: str, meter_kwh: float):
        self.device_id = device_id
        self.meter_kwh = meter_kwh
        self.load_kw = 0.0
        self.on = False
        self.online = True
        self._last = clock()

    def _advance(self) -> None:
        now = clock()
        if self.on and self.online:
            hours = (now - self._last).total_seconds() / 3600 * demo_speed
            self.meter_kwh += self.load_kw * hours
        self._last = now

    def read(self) -> PlugReading | None:
        self._advance()
        if not self.online:
            return None
        power_w = self.load_kw * 1000 if self.on else 0.0
        return PlugReading(self.on, NOMINAL_VOLTAGE, round(power_w / NOMINAL_VOLTAGE, 2),
                           round(power_w, 1), round(self.meter_kwh, 3))

    def switch(self, on: bool, load_kw: float = 0.0) -> bool:
        self._advance()
        if not self.online:
            return False
        self.on = on
        self.load_kw = load_kw if on else 0.0
        return True

    def set_online(self, online: bool) -> None:
        self._advance()
        self.online = online


_plugs: dict[str, SimulatedPlug] = {}


def get_plug(device_id: str) -> SimulatedPlug:
    if settings.plug_mode != "simulated":
        raise NotImplementedError(f"PLUG_MODE={settings.plug_mode} is not built yet")
    if device_id not in _plugs:
        # Give each simulated meter a distinct, realistic starting reading.
        seed = sum(ord(ch) for ch in device_id)
        _plugs[device_id] = SimulatedPlug(device_id, meter_kwh=1000 + seed * 1.37)
    return _plugs[device_id]


def reset_plugs() -> None:
    _plugs.clear()
