from typing import Optional, Dict, Any
from fastapi import APIRouter, Depends
from app.models.user import User
from app.core.security import get_current_user
from pydantic import BaseModel
from app.services.ai_service import ask_ai_about_file

router = APIRouter()


class AskRequest(BaseModel):
    question: str
    file_summary: Optional[Dict[str, Any]] = None


@router.post("/ask")
async def ask_ai(request: AskRequest, current_user: User = Depends(get_current_user)):
    """
    Accepts a question and an optional file summary.
    If file_summary is provided, answers grounded in the dataset metrics.
    If file_summary is omitted or empty, provides intelligent general guidance for the app.
    """
    answer = ask_ai_about_file(request.question, request.file_summary)
    return {"answer": answer}