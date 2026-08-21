import pytest
import io
import json

def test_apply_edit_api(client):
    client.post("/auth/register", json={"email": "u7@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u7@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    file_content = b"A,B\n1,2\n3,4"
    file = io.BytesIO(file_content)
    
    # Change A=1 to A=100
    changes = json.dumps([{"row_number": 1, "column": "A", "old_value": "1", "new_value": "100"}])
    
    response = client.post(
        "/apply-edit",
        files={"file": ("test.csv", file, "text/csv")},
        data={"changes": changes},
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

def test_suggest_edit_api(client):
    client.post("/auth/register", json={"email": "u8@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u8@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    file_content = b"A,B\n1,2"
    file = io.BytesIO(file_content)
    
    response = client.post(
        "/suggest-edit",
        files={"file": ("test.csv", file, "text/csv")},
        data={"instruction": "Change A to 100"},
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "proposed_changes" in data
