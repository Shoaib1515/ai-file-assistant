import os
import uuid
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.orm import Session
from app.services.file_parser import parse_file, get_file_summary
from app.core.validation import read_file_bounded_chunks, validate_file_format_and_safety
from app.db.database import get_db
from app.models.file_record import FileRecord
from app.models.user import User
from app.core.security import get_current_user

router = APIRouter()

STORAGE_DIR = "storage"
os.makedirs(STORAGE_DIR, exist_ok=True)


@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Accepts a CSV or Excel file, reads it in bounded stream chunks (max 10MB),
    validates magic-bytes signature and archive safety, parses it, saves it to
    disk using a UUID filename, and persists its metadata in PostgreSQL.
    """
    # 1. Read file in bounded stream chunks (raises HTTP 413 if > 10MB)
    contents = await read_file_bounded_chunks(file)

    # 2. Validate format, magic-bytes, and Zip safety (raises HTTP 400 if invalid)
    ext = validate_file_format_and_safety(file.filename, contents)

    # 3. Parse dataset into Pandas DataFrame (enforces row/column limits)
    try:
        df = parse_file(file.filename, contents)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    summary = get_file_summary(df)
    summary["filename"] = file.filename

    # 4. Generate safe UUID storage path with validated extension
    unique_name = f"{uuid.uuid4()}{ext}"
    storage_path = os.path.join(STORAGE_DIR, unique_name)
    with open(storage_path, "wb") as f:
        f.write(contents)

    # 5. Persist file metadata bound to current user in PostgreSQL
    file_record = FileRecord(
        user_id=current_user.id,
        filename=file.filename,
        storage_path=storage_path,
        total_rows=summary["total_rows"],
        total_columns=summary["total_columns"],
        missing_values=summary["missing_values"],
    )
    db.add(file_record)
    db.commit()
    db.refresh(file_record)

    summary["file_id"] = file_record.id

    return summary
