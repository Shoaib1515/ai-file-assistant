import pytest
import io
import json

def test_apply_edit_malformed_json(client):
    client.post("/auth/register", json={"email": "err1@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "err1@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    file_content = b"A,B\n1,2"
    file = io.BytesIO(file_content)
    
    # Malformed JSON string
    changes = "not-json"
    
    response = client.post(
        "/apply-edit",
        files={"file": ("test.csv", file, "text/csv")},
        data={"changes": changes},
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert response.status_code == 400
    assert "Invalid changes format" in response.json()["detail"]

def test_download_nonexistent_file(client):
    client.post("/auth/register", json={"email": "err2@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "err2@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    response = client.get(
        "/files/99999/download",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert response.status_code == 404
