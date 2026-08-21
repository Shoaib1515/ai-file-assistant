import pytest

def test_register_user(client):
    response = client.post("/auth/register", json={
        "email": "test@example.com",
        "password": "password123",
        "full_name": "Test User"
    })
    assert response.status_code == 200
    assert "access_token" in response.json()

def test_login_user(client):
    # Register first
    client.post("/auth/register", json={
        "email": "login@example.com",
        "password": "password123"
    })
    
    # Then login
    response = client.post("/auth/login", json={
        "email": "login@example.com",
        "password": "password123"
    })
    assert response.status_code == 200
    assert "access_token" in response.json()
