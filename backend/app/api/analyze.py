from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from app.models.user import User
from app.core.security import get_current_user
from app.services.file_parser import parse_file, get_sheet_names
from app.services.analyzer import analyze_dataframe
from app.core.validation import read_file_bounded_chunks

router = APIRouter()


@router.post("/analyze")
async def analyze_file(
    file: UploadFile = File(...),
    sheet_name: str | None = Form(None),
    current_user: User = Depends(get_current_user)
):
    try:
        contents = await read_file_bounded_chunks(file)
        sheet_names = get_sheet_names(file.filename, contents)
        active_sheet = sheet_name or (sheet_names[0] if sheet_names else None)
        df = parse_file(file.filename, contents, sheet_name=active_sheet)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    report = analyze_dataframe(df)
    report["filename"] = file.filename
    report["sheet_names"] = sheet_names
    report["active_sheet"] = active_sheet

    return report