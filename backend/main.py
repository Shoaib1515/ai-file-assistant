from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.api import auth, upload, ask, analyze, edit, files, file_actions
from app.db.database import engine, Base
from app.models import user, file_record  # noqa: F401

Base.metadata.create_all(bind=engine)

app = FastAPI(title="AI File Assistant")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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