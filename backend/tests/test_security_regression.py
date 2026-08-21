import pytest
import io
from app.models.file_record import FileRecord

def test_access_other_users_file(client, db_session):
    # User 1 uploads a file
    client.post("/auth/register", json={"email": "u1@e.com", "password": "password123"})
    login_resp1 = client.post("/auth/login", json={"email": "u1@e.com", "password": "password123"})
    token1 = login_resp1.json()["access_token"]
    
    file_content = b"col1,col2\n1,2"
    file = io.BytesIO(file_content)
    upload_resp = client.post(
        "/upload",
        files={"file": ("u1.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token1}"}
    )
    file_id = upload_resp.json()["file_id"]
    
    # User 2 tries to download User 1's file
    client.post("/auth/register", json={"email": "u2@e.com", "password": "password123"})
    login_resp2 = client.post("/auth/login", json={"email": "u2@e.com", "password": "password123"})
    token2 = login_resp2.json()["access_token"]
    
    response = client.get(f"/files/{file_id}/download", headers={"Authorization": f"Bearer {token2}"})
    # Expect 404 because user 2 cannot see user 1's file record
    assert response.status_code == 404

def test_delete_other_users_file(client, db_session):
    # User 1 uploads a file
    client.post("/auth/register", json={"email": "u3@e.com", "password": "password123"})
    login_resp1 = client.post("/auth/login", json={"email": "u3@e.com", "password": "password123"})
    token1 = login_resp1.json()["access_token"]
    
    file_content = b"col1,col2\n1,2"
    file = io.BytesIO(file_content)
    upload_resp = client.post(
        "/upload",
        files={"file": ("u3.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token1}"}
    )
    file_id = upload_resp.json()["file_id"]
    
    # User 2 tries to delete User 1's file
    client.post("/auth/register", json={"email": "u4@e.com", "password": "password123"})
    login_resp2 = client.post("/auth/login", json={"email": "u4@e.com", "password": "password123"})
    token2 = login_resp2.json()["access_token"]
    
    response = client.delete(f"/files/{file_id}", headers={"Authorization": f"Bearer {token2}"})
    # Expect 404 because user 2 cannot see user 1's file record
    assert response.status_code == 404
    # Verify file was not deleted
    assert db_session.query(FileRecord).filter(FileRecord.id == file_id).first() is not None
