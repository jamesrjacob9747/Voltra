# Voltra

Peer-to-peer EV charging for India: find a verified charger nearby, book it, charge, pay by UPI. Hosts earn from chargers and 15A sockets they already own.

Hackathon MVP. The core flow is **ChargeMatch → book → scan QR → live metered charge → bill → pay**, plus **ChargeSure**: if a charger goes offline, the booking moves to a nearby one with a ₹20 credit.

## Repo layout

```
backend/   FastAPI API, algorithms, simulated smart plug, tests
app/       Flutter app (to be added: run `flutter create` once Flutter is installed)
```

## Backend: run it

Requires Python 3.12+.

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env          # macOS/Linux: cp .env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- The first start creates the tables and seeds demo data (5 users, 8 chargers around Koramangala, Bengaluru).
- Interactive API docs: http://localhost:8000/docs
- A phone on the same Wi-Fi reaches it at `http://<laptop LAN IP>:8000`.
- SQLite by default. For Supabase, set `DATABASE_URL` in `.env` (see `.env.example`).

Run the tests:

```bash
cd backend
python -m pytest -q
```

## Demo data

| User | id | Role |
|---|---|---|
| Manoj, Rahul, Ayesha | 1–3 | Hosts |
| Priya | 4 | Host and driver (Nexon EV) |
| Arjun | 5 | Driver (Ather 450X: 3.0 kWh battery, 0.75 kW charger) |

Each charger's QR code is `voltra://charger/CHG001` … `CHG008`. CHG002 (Rahul) is about 350 m from CHG001 (Manoj), for the ChargeSure demo.

## Demo controls

| Action | Call |
|---|---|
| Take a charger offline (triggers ChargeSure) | `POST /admin/plugs/CHG001/online` with `{"online": false}` |
| Bring it back | same, with `{"online": true}` |
| Reset all demo data | `POST /admin/reset` |
| Speed up simulated charging | `DEMO_SPEED` in `.env` (default 30x; say so on stage) |

## Key endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/users`, `/users/{id}/vehicles` | Demo login picker, vehicle profile |
| GET | `/chargers?lat&lng&radius_km` | Nearby chargers with price and Charging Confidence |
| GET | `/chargers/{id}?user_id` | Details; exact address only after a confirmed booking |
| POST | `/match` | ChargeMatch: battery %, target %, ready-by → ranked chargers with estimates |
| POST/PATCH | `/bookings`, `/bookings/{id}` | Book; host accept/decline; cancel; arrive |
| GET | `/bookings/{id}/health` | Online check; offline returns ChargeSure alternatives |
| POST | `/bookings/{id}/transfer` | ChargeSure transfer with ₹20 credit |
| POST | `/sessions/start` | Scan QR → plug on, meter start |
| GET | `/sessions/{id}/live` | Live V, A, kW, kWh, ₹ (poll every 2 s) |
| POST | `/sessions/{id}/stop` | Plug off, meter end, bill |
| POST | `/payments/{booking_id}/order`, `/payments/verify`, `/payments/{booking_id}/demo-pay` | Razorpay test mode, or demo fallback |
| POST | `/reviews` | Two-way ratings |
| GET | `/host/{id}/dashboard` | Requests, upcoming, today's kWh and earnings, live session |

## How the numbers work

- **Energy needed** = (target% − current%) × battery kWh ÷ 0.9. **Power** = min(socket kW, vehicle charger kW).
- **Bill**: the driver pays kWh × price; Voltra keeps 15%, the host gets 85%. 1.85 kWh × ₹12 = ₹22.20, of which ₹3.33 goes to Voltra and ₹18.87 to the host. Money is stored as integer paise.
- **ChargeMatch** weights: distance 30, availability 25, reliability 20, price 15, power 10.
- **Charging Confidence**: IoT online 30, host confirmed 20, successful sessions 20, cancellation rate 10, recent activity 10, availability 10.
- **Time-of-day pricing**: +20% from 18:00 to 22:00, −20% from 00:00 to 06:00.

## Hardware

Metering is simulated for now (`PLUG_MODE=simulated`). A real metering smart plug (for example a Shelly Plug) can be added later behind the same `read()` / `switch()` interface in `backend/app/services/plug.py`, without changing the app.
