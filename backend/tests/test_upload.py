import pytest
import io

def test_upload_csv(client, db_session):
    # Create a small valid CSV file
    file_content = b"col1,col2\n1,2"
    file = io.BytesIO(file_content)
    
    response = client.post(
        "/upload",
        files={"file": ("test.csv", file, "text/csv")}
    )
    assert response.status_code == 401

def test_upload_with_auth(client):
    # Register and login first to get a token
    client.post("/auth/register", json={"email": "u@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    file_content = b"col1,col2\n1,2"
    file = io.BytesIO(file_content)
    
    response = client.post(
        "/upload",
        files={"file": ("test.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token}"}
    )
    # The file should upload successfully.
    assert response.status_code == 200
    assert "file_id" in response.json()

def test_upload_oversized_file(client):
    client.post("/auth/register", json={"email": "u2@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u2@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    # 11MB file
    file_content = b"a" * (11 * 1024 * 1024)
    file = io.BytesIO(file_content)
    
    response = client.post(
        "/upload",
        files={"file": ("large.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 413

def test_upload_invalid_type(client):
    client.post("/auth/register", json={"email": "u3@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u3@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    file_content = b"some content"
    file = io.BytesIO(file_content)
    
    response = client.post(
        "/upload",
        files={"file": ("test.txt", file, "text/plain")},
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 400
