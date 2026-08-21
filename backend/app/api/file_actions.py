import json
from fastapi import APIRouter, Depends, HTTPException, Form
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.models.file_record import FileRecord
from app.models.user import User
from app.core.security import get_current_user
from app.services.file_parser import parse_file
from app.services.analyzer import analyze_dataframe
from app.services.ai_service import suggest_edit
from app.services.editor import apply_changes, dataframe_to_excel_bytes
import io
import os

router = APIRouter()

SAMPLE_SIZE_FOR_AI = 50


def _load_file_record(file_id: int, current_user: User, db: Session) -> FileRecord:
    record = (
        db.query(FileRecord)
        .filter(FileRecord.id == file_id, FileRecord.user_id == current_user.id)
        .first()
    )
    if record is None:
        raise HTTPException(status_code=404, detail="File not found")
    if record.storage_path is None:
        raise HTTPException(status_code=410, detail="This file's content is no longer available")
    return record


def _read_stored_bytes(record: FileRecord) -> bytes:
    try:
        with open(record.storage_path, "rb") as f:
            return f.read()
    except FileNotFoundError:
        raise HTTPException(status_code=410, detail="This file's content is no longer available")


@router.post("/files/{file_id}/analyze")
def analyze_stored_file(
    file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Re-analyzes a previously uploaded file, using the copy saved on
    disk at upload time — no need to re-pick the file on the device.
    """
    record = _load_file_record(file_id, current_user, db)
    contents = _read_stored_bytes(record)

    df = parse_file(record.filename, contents)
    report = analyze_dataframe(df)
    report["filename"] = record.filename
    return report


@router.post("/files/{file_id}/suggest-edit")
def suggest_edit_stored_file(
    file_id: int,
    instruction: str = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Same as /suggest-edit, but works off the server-stored copy of a
    previously uploaded file rather than a freshly picked one.
    """
    record = _load_file_record(file_id, current_user, db)
    contents = _read_stored_bytes(record)

    df = parse_file(record.filename, contents)
    sample_df = df.head(SAMPLE_SIZE_FOR_AI)
    sample_rows = [
        {"row_number": int(idx) + 1, **row}
        for idx, row in zip(sample_df.index, sample_df.to_dict('records'))
    ]

    file_summary = {"columns": list(df.columns)}
    proposed_changes = suggest_edit(instruction, file_summary, sample_rows)

    return {
        "instruction": instruction,
        "proposed_changes": proposed_changes,
        "change_count": len(proposed_changes),
    }

@router.post("/files/{file_id}/apply-edit")
def apply_edit_stored_file(
    file_id: int,
    changes: str = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Applies approved changes to the server-stored copy, overwrites it
    on disk with the updated version, and returns the updated file.

    Since edits are always written back out as .xlsx (dataframe_to_excel_bytes
    always produces an Excel file, regardless of the original format), the
    stored file's extension and filename are updated to match — otherwise a
    later analyze/edit call would try to parse Excel bytes as CSV (or vice
    versa) based on a now-stale filename, and crash.
    """
    record = _load_file_record(file_id, current_user, db)
    contents = _read_stored_bytes(record)

    df = parse_file(record.filename, contents)

    try:
        changes_list = json.loads(changes)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid changes format.")

    updated_df = apply_changes(df, changes_list)
    excel_bytes = dataframe_to_excel_bytes(updated_df)

    # The output is always .xlsx now, so give the stored copy a matching
    # extension. Keep the same base name (before the last dot) either way.
    old_path = record.storage_path
    new_storage_path = os.path.splitext(old_path)[0] + ".xlsx"

    with open(new_storage_path, "wb") as f:
        f.write(excel_bytes)

    # Clean up the old file on disk if the extension actually changed.
    if new_storage_path != old_path and os.path.exists(old_path):
        os.remove(old_path)

    # Update the filename to match too, so future /analyze or /suggest-edit
    # calls on this file_id parse it as Excel, not whatever it was before.
    old_filename_base = os.path.splitext(record.filename)[0]
    new_filename = old_filename_base + ".xlsx"

    record.storage_path = new_storage_path
    record.filename = new_filename
    db.commit()

    return StreamingResponse(
        io.BytesIO(excel_bytes),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename=updated_{new_filename}"},
    )