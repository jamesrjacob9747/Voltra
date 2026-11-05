from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from .db import SessionLocal, create_schema
from .models import User
from .routers import admin, bookings, chargers, host, impact, match, payments, reviews, sessions, telemetry, users
from .seed import seed
from .services import plug


@asynccontextmanager
async def lifespan(_: FastAPI):
    create_schema()
    with SessionLocal() as db:
        if db.scalar(select(User.id)) is None:
            seed(db)
    yield


app = FastAPI(title="Voltra API", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

for module in (users, chargers, match, bookings, sessions, payments, reviews, host, impact, telemetry, admin):
    app.include_router(module.router)


@app.get("/health")
def health():
    # Booking times are server-local wall clock; the app anchors its own clock to this.
    return {"ok": True, "server_time": plug.clock().isoformat(timespec="seconds")}
