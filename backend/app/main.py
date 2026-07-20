from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import school, payment, auth

app = FastAPI(
    title="FUTA Backend API",
    description="Service API pour FUTA - Solutions éducatives et fintech pour la RDC/ROC",
    version="1.0.0"
)

import os

# Enable CORS for frontend clients (web and mobile simulators)
allow_origins_raw = os.getenv("ALLOWED_ORIGINS", "*")
if allow_origins_raw == "*":
    # In FastAPI, allow_credentials=True cannot be used with a wildcard ("*") origin.
    # To support local developer environments, we specify common origins explicitly.
    allow_origins = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:8000",
        "https://futa-1c8d8.firebaseapp.com",
        "https://futa-1c8d8.web.app",
    ]
else:
    allow_origins = allow_origins_raw.split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth.router)
app.include_router(school.router)
app.include_router(payment.router)


@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": "FUTA API",
        "description": "Portail Cloud Run d'orchestration M-Pesa et d'ingestion scolaire",
        "language": "fr"
    }
