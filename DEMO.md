# Voltra demo runbook

Everything you need on demo day: set up, run the 5-minute pitch with the live demo, and recover if something breaks.

## 1. Before you present (15 minutes)

1. **Network:** connect the laptop and the demo phone to the **same Wi-Fi or hotspot**. Avoid networks with HTTPS inspection (college/office firewalls): the map tiles won't load.
2. **Start the backend** (leave this terminal open):
   ```bash
   cd backend
   .venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
   Check it: http://localhost:8000/health returns `"ok": true`.
3. **Find the laptop's IP** (on the hotspot it was `172.20.10.3`; check again):
   ```bash
   ipconfig
   ```
4. **Install the app on the phone** (USB debugging on, phone plugged in):
   ```bash
   cd app
   flutter run --dart-define=API_URL=http://LAPTOP_IP:8000
   ```
   On the emulator, plain `flutter run` is enough (it uses `10.0.2.2`).
5. **Reset the demo data:** in the app, **Demo controls → Reset all demo data**.
6. **Print or show the QR stickers:** open `qr/index.html`. You need CHG001 (Manoj) and CHG002 (Rahul).
7. **Have the backup ready:** the screen recordings from rehearsal (see section 4), open in a video player.

## 2. The 5-minute pitch

| Time | Slide / action | What to say |
|---|---|---|
| 0:00–0:40 | Hook + problem slides | “What if the charger your EV needs is already 300 m away?” |
| 0:40–1:20 | Insight slide | The chargers exist; they’re invisible, inaccessible, unmonetised. |
| 1:20–3:30 | **Live demo** (below) | Narrate what the judge sees, not the code. |
| 3:30–4:15 | Differentiation + tech slides | ChargeMatch, SmartMeter, ChargeSure. The server owns every rupee. |
| 4:15–4:45 | Business model | 15% commission; ChargeSure credit is Voltra-funded. |
| 4:45–5:00 | Vision | “We’re unlocking the chargers already around us.” |

### Live demo script (about 2 minutes)

**Part A: a charge, start to finish (Arjun, driver)**

1. Log in as **Arjun** → **Find me a charge**.
   Say: *“I tell Voltra what I need, not where to go: 25% to 80% by 3 PM.”*
2. **Find my charger.** Point at the best match: distance, ₹/kWh, Charging Confidence, ready-by time and cost.
   Say: *“It knows my Ather charges at 0.75 kW, so it estimates 2 h 27 min and about ₹20.”*
3. **Reserve** → confirmed instantly; the exact address unlocks.
4. **Scan QR to start charging** → scan CHG002’s sticker (or **Enter code** → `CHG002`).
5. Live screen: kWh and ₹ count up.
   Say: *“That’s the smart meter, not an estimate. The demo runs 30× faster, as the badge says.”*
6. **Stop charging** → **Stop**. The bill: kWh × rate, 85% to the host, 15% to Voltra.
7. **Pay with UPI** → **Approve** → rate the host 5 stars.

**Part B: ChargeSure (the differentiator)**

1. **Back to map** → tap **Manoj’s Home Charger** in the list → **Book this charger** → **Confirm booking**.
2. **Switch Manoj’s charger off:** back to the map → switch-user icon (top right) → **Demo controls** → turn off **Manoj’s Home Charger** → back → **Arjun** → receipt icon (**My bookings**) → the Manoj booking.
   (Smoother with two devices: keep Arjun on the booking screen and flip the switch on the second one.)
3. Within a few seconds the **ChargeSure** panel appears with ranked nearby chargers.
   Say: *“Other apps say ‘sorry’. Voltra rebooks you in one tap and pays you ₹20 for the trouble.”*
4. **Move my booking here** → new booking with the credit.

**Optional, if time:** log in as **Rahul** (host) to show the dashboard: earnings, the live session card, Accept/Decline on requests.

## 3. If something breaks

| Problem | Do this |
|---|---|
| App says it can’t reach the server | Backend terminal still running? Phone on the same network? Wrong IP → re-run `flutter run` with the right `API_URL`. |
| Map is grey | Tiles need internet without HTTPS inspection. Carry on: the charger list under the map still works. |
| Camera won’t read the QR | **Enter code** → `CHG002`. |
| Payment sheet misbehaves | It’s demo mode; **Approve** only calls our server. If it fails, say “payment is mocked for the hackathon” and move on. |
| Demo data is messy | **Demo controls → Reset all demo data**. |
| Anything else | Play the backup recording and talk over it. |

## 4. Backup recordings

Made during rehearsal on the emulator (portrait MP4s, no sound):

- `demo-backup/1-charge-and-pay.mp4`: Part A
- `demo-backup/2-chargesure.mp4`: Part B

They live outside the repo, in `D:\Voltra\demo-backup\`, so the repo stays small.

## 5. Judge questions

- **“Bolt.Earth already exists.”** It proves the model. We differ on matching by need, live reliability scoring, measured billing on ordinary sockets and automatic rebooking.
- **“Strangers at my house?”** Hosts set hours and approve bookings, users are verified, the exact address is hidden until confirmed, and ratings go both ways.
- **“How is billing trustworthy?”** The smart meter measures energy; the server computes the bill. The phone never sends a price or a reading.
- **“What if the charger fails?”** That’s ChargeSure. Show Part B.
- **“Is the hardware real?”** The plug is simulated for the hackathon, behind the same interface a real metering smart plug uses.
