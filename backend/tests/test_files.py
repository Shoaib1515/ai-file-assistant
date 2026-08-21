import pytest
import io
import os
import json
from app.models.file_record import FileRecord

def test_get_all_files(client):
    client.post("/auth/register", json={"email": "u8@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u8@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    # Upload a file first
    file_content = b"col1,col2\n1,2"
    file = io.BytesIO(file_content)
    client.post(
        "/upload",
        files={"file": ("test.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token}"}
    )
    
    response = client.get("/files", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert len(response.json()) >= 1

def test_delete_file(client, db_session):
    client.post("/auth/register", json={"email": "u9@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u9@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    # Upload
    file_content = b"col1,col2\n1,2"
    file = io.BytesIO(file_content)
    upload_resp = client.post(
        "/upload",
        files={"file": ("del.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token}"}
    )
    file_id = upload_resp.json()["file_id"]
    storage_path = db_session.query(FileRecord).filter(FileRecord.id == file_id).first().storage_path
    
    # Delete
    response = client.delete(f"/files/{file_id}", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    
    # Verify DB and File deleted
    assert db_session.query(FileRecord).filter(FileRecord.id == file_id).first() is None
    assert not os.path.exists(storage_path)

def test_download_file(client):
    client.post("/auth/register", json={"email": "u10@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u10@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    # Upload
    file_content = b"col1,col2\n1,2"
    file = io.BytesIO(file_content)
    upload_resp = client.post(
        "/upload",
        files={"file": ("down.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token}"}
    )
    file_id = upload_resp.json()["file_id"]
    
    # Download
    response = client.get(f"/files/{file_id}/download", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.content == file_content
