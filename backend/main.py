import os

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.api import auth, upload, ask, analyze, edit, files, file_actions
from app.db.database import engine, Base
from app.models import user, file_record  # noqa: F401

Base.metadata.create_all(bind=engine)

app_env = os.getenv("APP_ENV", "development").lower()
allowed_origins_raw = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173",
)
allowed_origins = [
    origin.strip()
    for origin in allowed_origins_raw.split(",")
    if origin.strip()
]

if app_env == "production" and not allowed_origins:
    raise RuntimeError("ALLOWED_ORIGINS environment variable must be configured for production.")

app = FastAPI(title="AI File Assistant")
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins if app_env == "production" else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)

app.include_router(upload.router)
app.include_router(ask.router)
app.include_router(analyze.router)
app.include_router(edit.router)
app.include_router(files.router)
app.include_router(file_actions.router)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"Unhandled error: {exc}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Something went wrong on our end. Please try again."}
    )


@app.get("/")
def read_root():
    return {"message": "AI File Assistant backend is running!"}