from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from app.models.user import User
from app.core.security import get_current_user
from fastapi.responses import StreamingResponse
from app.services.file_parser import parse_file
from app.services.ai_service import suggest_edit
from app.services.editor import apply_changes, dataframe_to_excel_bytes
from app.core.validation import read_file_bounded_chunks
import json
import io

router = APIRouter()

SAMPLE_SIZE_FOR_AI = 50


@router.post("/suggest-edit")
async def suggest_edit_endpoint(
    file: UploadFile = File(...),
    instruction: str = Form(...),
    current_user: User = Depends(get_current_user),
):
    contents = await read_file_bounded_chunks(file)

    try:
        df = parse_file(file.filename, contents)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

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
        "change_count": len(proposed_changes)
    }


@router.post("/apply-edit")
async def apply_edit_endpoint(
    file: UploadFile = File(...),
    changes: str = Form(...),
    current_user: User = Depends(get_current_user),
):
    """
    Accepts the original file and an approved list of changes
    (as a JSON string), applies them, and returns the updated file.
    """
    contents = await read_file_bounded_chunks(file)

    try:
        df = parse_file(file.filename, contents)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        changes_list = json.loads(changes)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid changes format.")

    updated_df = apply_changes(df, changes_list)
    excel_bytes = dataframe_to_excel_bytes(updated_df)

    return StreamingResponse(
        io.BytesIO(excel_bytes),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=updated_file.xlsx"}
    )