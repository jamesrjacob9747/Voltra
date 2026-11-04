"""Time-of-day pricing (PRD Algorithms 4): +20% evening peak, -20% night."""

PEAK_HOURS = range(18, 22)
OFF_PEAK_HOURS = range(0, 6)


def price_at(base_paise: int, hour: int) -> int:
    if hour in PEAK_HOURS:
        return round(base_paise * 1.2)
    if hour in OFF_PEAK_HOURS:
        return round(base_paise * 0.8)
    return base_paise
