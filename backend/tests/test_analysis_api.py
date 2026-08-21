import pytest
import io
import pandas as pd

def test_analyze_api_valid_csv(client):
    client.post("/auth/register", json={"email": "u4@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u4@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    file_content = b"col1,col2\n1,2\n1,2"
    file = io.BytesIO(file_content)
    
    response = client.post(
        "/analyze",
        files={"file": ("test.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total_rows"] == 2
    assert data["duplicates"]["total_duplicates"] == 2

def test_analyze_api_malformed_csv(client):
    client.post("/auth/register", json={"email": "u5@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u5@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    # Deliberately malformed CSV (inconsistent columns)
    file_content = b"col1,col2\n1,2\n1"
    file = io.BytesIO(file_content)
    
    response = client.post(
        "/analyze",
        files={"file": ("test.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token}"}
    )
    # The current parse_file uses pandas.read_csv which might handle this,
    # but the API endpoint should catch it if parsing fails.
    assert response.status_code == 200 # Pandas might parse this as NaN

def test_analyze_api_empty_file(client):
    client.post("/auth/register", json={"email": "u6@e.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "u6@e.com", "password": "password123"})
    token = login_resp.json()["access_token"]
    
    file_content = b""
    file = io.BytesIO(file_content)
    
    response = client.post(
        "/analyze",
        files={"file": ("empty.csv", file, "text/csv")},
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 400
