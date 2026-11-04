"""Writes a printable QR sheet for the seeded chargers: qr/index.html + one SVG each.

Run from backend/:  python -m scripts.make_qr_codes
Each code holds voltra://charger/<device_id>, which the app scans to start a session.
"""

from html import escape
from pathlib import Path

import qrcode
import qrcode.image.svg

from app.seed import CHARGERS

OUT = Path(__file__).resolve().parents[2] / "qr"


def main() -> None:
    OUT.mkdir(exist_ok=True)
    cards = []
    for i, (name, *_rest) in enumerate(CHARGERS, 1):
        device_id = f"CHG{i:03d}"
        img = qrcode.make(f"voltra://charger/{device_id}", image_factory=qrcode.image.svg.SvgPathImage, box_size=12)
        img.save(OUT / f"{device_id}.svg")
        cards.append(
            f'<div class="card"><img src="{device_id}.svg" alt="QR for {device_id}">'
            f"<h2>{escape(name)}</h2><p>Code: <b>{device_id}</b></p></div>"
        )

    (OUT / "index.html").write_text(
        "<!doctype html><meta charset='utf-8'><title>Voltra charger QR codes</title>"
        "<style>body{font-family:sans-serif;display:flex;flex-wrap:wrap;gap:24px;padding:24px}"
        ".card{border:2px solid #0E1A2B;border-radius:16px;padding:16px;width:260px;text-align:center}"
        ".card img{width:220px}h2{font-size:18px;margin:8px 0 4px}p{margin:0;color:#4A5563}"
        "@media print{.card{break-inside:avoid}}</style>" + "".join(cards),
        encoding="utf-8",
    )
    print(f"Wrote {len(cards)} QR codes to {OUT}")


if __name__ == "__main__":
    main()
