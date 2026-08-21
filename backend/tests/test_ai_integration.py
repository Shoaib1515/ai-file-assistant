import pytest
from unittest.mock import MagicMock, patch
from app.services.ai_service import ask_ai_about_file, suggest_edit
from google.genai import errors

@patch("app.services.ai_service.get_ai_client")
def test_ask_ai_about_file_success(mock_get_client):
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = "The dataset has 100 rows."
    mock_client.models.generate_content.return_value = mock_response
    mock_get_client.return_value = mock_client
    
    question = "How many rows?"
    file_summary = {"filename": "test.csv", "total_rows": 100}
    
    answer = ask_ai_about_file(question, file_summary)
    assert answer == "The dataset has 100 rows."

@patch("app.services.ai_service.get_ai_client")
def test_ask_ai_about_file_server_error(mock_get_client):
    mock_client = MagicMock()
    # Simulate ServerError on all 3 attempts
    mock_client.models.generate_content.side_effect = errors.ServerError(code=500, response_json={})
    mock_get_client.return_value = mock_client
    
    question = "How many rows?"
    file_summary = {"filename": "test.csv", "total_rows": 100}
    
    answer = ask_ai_about_file(question, file_summary)
    assert answer == "The AI service is currently busy. Please try again in a moment."
    assert mock_client.models.generate_content.call_count == 3

@patch("app.services.ai_service.get_ai_client")
def test_suggest_edit_success(mock_get_client):
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = '[{"row_number": 1, "column": "A", "old_value": "0", "new_value": "1"}]'
    mock_client.models.generate_content.return_value = mock_response
    mock_get_client.return_value = mock_client
    
    instruction = "Change A to 1"
    file_summary = {"columns": ["A"]}
    sample_rows = [{"A": "0"}]
    
    changes = suggest_edit(instruction, file_summary, sample_rows)
    assert len(changes) == 1
    assert changes[0]["new_value"] == "1"

@patch("app.services.ai_service.get_ai_client")
def test_suggest_edit_malformed_json(mock_get_client):
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = 'invalid json'
    mock_client.models.generate_content.return_value = mock_response
    mock_get_client.return_value = mock_client
    
    instruction = "Change A to 1"
    file_summary = {"columns": ["A"]}
    sample_rows = [{"A": "0"}]
    
    changes = suggest_edit(instruction, file_summary, sample_rows)
    assert changes == []
