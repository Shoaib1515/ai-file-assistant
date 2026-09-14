import pytest
from unittest.mock import MagicMock, patch
from app.services.ai_service import ask_ai_about_file, suggest_edit

@patch("app.services.ai_service.call_groq")
@patch("app.services.ai_service.call_gemini")
def test_ask_ai_about_file_success(mock_gemini, mock_groq):
    mock_groq.return_value = "The dataset has 100 rows."
    mock_gemini.return_value = "The dataset has 100 rows."
    
    question = "How many rows?"
    file_summary = {"filename": "test.csv", "total_rows": 100}
    
    answer = ask_ai_about_file(question, file_summary)
    assert answer == "The dataset has 100 rows."

@patch("app.services.ai_service.call_groq")
@patch("app.services.ai_service.call_gemini")
def test_ask_ai_about_file_server_error(mock_gemini, mock_groq):
    mock_groq.side_effect = Exception("Server error")
    mock_gemini.side_effect = Exception("Server error")
    
    question = "How many rows?"
    file_summary = {"filename": "test.csv", "total_rows": 100}
    
    answer = ask_ai_about_file(question, file_summary)
    assert "Unable to process AI question request at this time" in answer

@patch("app.services.ai_service.call_groq")
@patch("app.services.ai_service.call_gemini")
def test_suggest_edit_success(mock_gemini, mock_groq):
    mock_groq.return_value = '[{"row_number": 1, "column": "A", "old_value": "0", "new_value": "1"}]'
    mock_gemini.return_value = '[{"row_number": 1, "column": "A", "old_value": "0", "new_value": "1"}]'
    
    instruction = "Change A to 1"
    file_summary = {"columns": ["A"]}
    sample_rows = [{"A": "0"}]
    
    changes = suggest_edit(instruction, file_summary, sample_rows)
    assert len(changes) == 1
    assert changes[0]["new_value"] == "1"

@patch("app.services.ai_service.call_groq")
@patch("app.services.ai_service.call_gemini")
def test_suggest_edit_malformed_json(mock_gemini, mock_groq):
    mock_groq.return_value = 'invalid json'
    mock_gemini.return_value = 'invalid json'
    
    instruction = "Change A to 1"
    file_summary = {"columns": ["A"]}
    sample_rows = [{"A": "0"}]
    
    changes = suggest_edit(instruction, file_summary, sample_rows)
    assert changes == []
