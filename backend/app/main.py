from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from .db import Base, SessionLocal, engine
from .models import User
from .routers import admin, bookings, chargers, host, match, payments, reviews, sessions, telemetry, users
from .seed import seed


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        if db.scalar(select(User.id)) is None:
            seed(db)
    yield


app = FastAPI(title="Voltra API", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

for module in (users, chargers, match, bookings, sessions, payments, reviews, host, telemetry, admin):
    app.include_router(module.router)


@app.get("/health")
def health():
    return {"ok": True}
