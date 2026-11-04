"""Billing (PRD Algorithms 5). The driver sees one all-in price; Voltra keeps the fee from it.

All money is integer paise. 1.85 kWh x Rs 12 = Rs 22.20 -> fee Rs 3.33, host Rs 18.87.
"""

from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal


@dataclass(frozen=True)
class Bill:
    energy_kwh: float
    total_paise: int
    platform_fee_paise: int
    host_share_paise: int


def _round(value: Decimal) -> int:
    return int(value.quantize(Decimal(1), rounding=ROUND_HALF_UP))


def metered_kwh(meter_start: float, meter_end: float) -> float:
    # Round to Wh so float noise (1544.27 - 1542.42 = 1.8499999) never moves a paisa.
    return round(max(0.0, meter_end - meter_start), 3)


def compute_bill(energy_kwh: float, price_per_kwh_paise: int, fee_bps: int) -> Bill:
    total = _round(Decimal(str(energy_kwh)) * price_per_kwh_paise)
    fee = _round(Decimal(total) * fee_bps / 10_000)
    return Bill(energy_kwh, total, fee, total - fee)
