# Voltra

[![CI](https://github.com/jamesrjacob9747/Voltra/actions/workflows/ci.yml/badge.svg)](https://github.com/jamesrjacob9747/Voltra/actions/workflows/ci.yml)

**Live API:** https://voltra-nrj1.onrender.com ([docs](https://voltra-nrj1.onrender.com/docs)) · Render + Supabase, Singapore

**Android app:** download `Voltra.apk` from the [latest release](https://github.com/jamesrjacob9747/Voltra/releases/latest). It uses the live API, so no laptop is needed. Payments run in Razorpay test mode.

Peer-to-peer EV charging for India: find a verified charger nearby, book it, charge, pay by UPI. Hosts earn from chargers and 15A sockets they already own.

Hackathon MVP. The core flow is **ChargeMatch → book → scan QR → live metered charge → bill → pay**, plus **ChargeSure**: if a charger goes offline, the booking moves to a nearby one with a ₹20 credit.

## Repo layout

```
backend/   FastAPI API, algorithms, simulated smart plug, tests
app/       Flutter app (Android): driver and host modes
qr/        Printable QR stickers for the 8 demo chargers (open qr/index.html)
DEMO.md    Stage runbook: setup, the 5-minute script, fallbacks
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
- SQLite by default. For Supabase, set `DATABASE_URL` in `.env` to the **Session pooler** URI (see `.env.example`). The laptop is far from Supabase's servers, so requests are slower locally than when hosted. Comment the line out to go back to SQLite.
- On Postgres, startup also switches on row level security for every table, which closes Supabase's public REST API to these tables. The server's own connection keeps full access.
- `DEMO_ENDPOINTS=false` turns off the demo controls (`/admin/*`, demo payment). With `ADMIN_TOKEN` set, they require that value in an `X-Admin-Token` header.

Tests and lint (dev tools are in `requirements-dev.txt`):

```bash
cd backend
pip install -r requirements-dev.txt
python -m pytest -q
python -m ruff check . && python -m ruff format --check .
```

## App: run it

Built with Flutter 3.47. Needs an Android emulator or phone (`flutter devices` should list it).

```bash
cd app
flutter pub get
flutter run                                              # emulator: reaches the laptop at 10.0.2.2:8000
flutter run --dart-define=API_URL=http://LAPTOP_IP:8000  # real phone on the same Wi-Fi
```

Debug builds may use plain HTTP (the laptop). **Release builds are HTTPS-only**, so build them for the hosted API (see [Deploy](#deploy)).

```bash
flutter test      # unit tests
flutter analyze
```

## Demo data

| User | id | Role |
|---|---|---|
| Manoj, Rahul, Ayesha | 1–3 | Hosts |
| Priya | 4 | Host and driver (Nexon EV) |
| Arjun | 5 | Driver (Ather 450X: 3.0 kWh battery, 0.75 kW charger) |

Each charger's QR code is `voltra://charger/CHG001` … `CHG008`. CHG002 (Rahul) is about 350 m from CHG001 (Manoj), for the ChargeSure demo.

## Hosts add chargers

On the host dashboard, **Add charger** opens a form: name, address, a pin placed on the map, connector, max power, price per kWh, opening hours and instant booking. The new charger gets the next code (`CHG009`, …), which the app shows straight away. The host writes it next to the socket, and drivers type it with **Enter code** on the scan screen to start charging. New chargers are listed as unverified, and drivers see only an approximate pin until their booking is confirmed. Hosts see all their chargers, with codes, under **My chargers**.

## Demo controls

In the app: **Demo controls** on the login screen (charger on/off switches, reset). Or over HTTP:

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
| POST | `/chargers` | Host adds a charger (hosts only; validated); returns its new code |
| GET | `/host/{id}/chargers` | The host's own chargers, with codes and exact location |

## How the numbers work

- **Energy needed** = (target% − current%) × battery kWh ÷ 0.9. **Power** = min(socket kW, vehicle charger kW).
- **Bill**: the driver pays kWh × price; Voltra keeps 15%, the host gets 85%. 1.85 kWh × ₹12 = ₹22.20, of which ₹3.33 goes to Voltra and ₹18.87 to the host. Money is stored as integer paise.
- **ChargeMatch** weights: distance 30, availability 25, reliability 20, price 15, power 10.
- **Charging Confidence**: IoT online 30, host confirmed 20, successful sessions 20, cancellation rate 10, recent activity 10, availability 10.
- **Time-of-day pricing**: +20% from 18:00 to 22:00, −20% from 00:00 to 06:00.

## Deploy

The backend runs on **Render** (free web service) and the database on **Supabase**, both in **Singapore**, so each database query takes 1–2 ms.

1. **Supabase:** create a project in Southeast Asia (Singapore). Copy **Connect → Session pooler** as the `DATABASE_URL`.
2. **Render** → New → Web Service → this GitHub repo:

   | Setting | Value |
   |---|---|
   | Region | Singapore |
   | Branch | `main` |
   | Root Directory | `backend` |
   | Runtime | Python 3 |
   | Build Command | `pip install -r requirements.txt` |
   | Start Command | `uvicorn app.main:app --host 0.0.0.0 --port $PORT` |
   | Health Check Path | `/health` |
   | Instance Type | Free |

3. **Environment variables** on Render: `DATABASE_URL`, `ADMIN_TOKEN` (long random value), `TIMEZONE=Asia/Kolkata`, `DEMO_SPEED=30`, `DEMO_ENDPOINTS=true`, `PYTHON_VERSION=3.12.8`. Secrets live only in Render's dashboard and your local `backend/.env`, never in git.
4. **App for the hosted API:**
   ```bash
   cd app
   flutter build apk --release --split-per-abi --dart-define=API_URL=https://YOUR-SERVICE.onrender.com --dart-define=ADMIN_TOKEN=YOUR_TOKEN
   ```
   Install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` on the phone.

Every merge to `main` redeploys. The free instance sleeps after 15 idle minutes, and its first request then takes 30–60 s. Open `/health` a couple of minutes before a demo.

## Hardware

Metering is simulated for now (`PLUG_MODE=simulated`). A real metering smart plug (for example a Shelly Plug) can be added later behind the same `read()` / `switch()` interface in `backend/app/services/plug.py`, without changing the app.
