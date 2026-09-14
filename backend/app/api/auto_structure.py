import os
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.orm import Session
from app.models.user import User
from app.core.security import get_current_user
from app.db.database import get_db
from app.models.file_record import FileRecord
from app.services.file_parser import parse_file
from app.services.auto_structurer import auto_structure_dataframe
from app.core.validation import read_file_bounded_chunks

router = APIRouter()


@router.post("/auto-structure")
async def auto_structure_uploaded_file(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    """
    1-Tap Auto-Structure Endpoint:
    Accepts raw multipart file, parses, structures, cleans, and returns full transformation metrics + preview.
    """
    try:
        contents = await read_file_bounded_chunks(file)
        df = parse_file(file.filename, contents)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    result = auto_structure_dataframe(df, filename=file.filename)
    return result


@router.post("/auto-structure/{file_id}")
@router.post("/files/{file_id}/auto-structure")
async def auto_structure_existing_file(
    file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    1-Tap Auto-Structure for a file already stored in user's library.
    """
    file_record = (
        db.query(FileRecord)
        .filter(FileRecord.id == file_id, FileRecord.user_id == current_user.id)
        .first()
    )
    if not file_record:
        raise HTTPException(status_code=404, detail="File not found")
    if not file_record.storage_path or not os.path.exists(file_record.storage_path):
        raise HTTPException(status_code=410, detail="This file's content is no longer available")

    with open(file_record.storage_path, "rb") as f:
        contents = f.read()

    df = parse_file(file_record.filename, contents)
    result = auto_structure_dataframe(df, filename=file_record.filename)
    return result
