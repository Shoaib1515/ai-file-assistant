from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.models.file_record import FileRecord
from app.models.user import User
from app.core.security import get_current_user
from fastapi.responses import FileResponse, JSONResponse
import os

router = APIRouter()


@router.get("/files")
def get_all_files(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns metadata for files uploaded by the currently authenticated user,
    most recent first.
    """
    records = (
        db.query(FileRecord)
        .filter(FileRecord.user_id == current_user.id)
        .order_by(FileRecord.uploaded_at.desc())
        .all()
    )

    return [
        {
            "file_id": record.id,
            "filename": record.filename,
            "total_rows": record.total_rows,
            "total_columns": record.total_columns,
            "missing_values": record.missing_values,
            "uploaded_at": record.uploaded_at.isoformat() if record.uploaded_at else None,
        }
        for record in records
    ]
@router.get("/files/{file_id}/download")
def download_file(
    file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    record = db.query(FileRecord).filter(FileRecord.id == file_id, FileRecord.user_id == current_user.id).first()
    if not record or not record.storage_path or not os.path.exists(record.storage_path):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(record.storage_path, media_type="application/octet-stream", filename=record.filename)

@router.delete("/files/{file_id}")
def delete_file(
    file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    record = db.query(FileRecord).filter(FileRecord.id == file_id, FileRecord.user_id == current_user.id).first()
    if not record:
        raise HTTPException(status_code=404, detail="File not found")
    if record.storage_path and os.path.exists(record.storage_path):
        os.remove(record.storage_path)
    db.delete(record)
    db.commit()
    return {"message": "File deleted successfully"}