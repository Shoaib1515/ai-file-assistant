from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from app.models.user import User
from app.core.security import get_current_user
from app.services.file_parser import parse_file
from app.services.analyzer import analyze_dataframe
from app.core.validation import read_file_bounded_chunks

router = APIRouter()


@router.post("/analyze")
async def analyze_file(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    try:
        contents = await read_file_bounded_chunks(file)
        df = parse_file(file.filename, contents)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    report = analyze_dataframe(df)
    report["filename"] = file.filename

    return report