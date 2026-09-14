import pytest
import io
import pandas as pd
from app.services.file_parser import parse_file
from app.services.analyzer import analyze_dataframe

MESSY_SAMPLE_CSV = b"""# Test File for Unstructured/Messy Data Parsing
# Created for testing robust data ingestion pipelines
,,,
id,name,email,age,city,status
1,Ali Ahmed,ali@example.com,25,Lahore,Active
2,Sana Khan,sana@example.com,30,"Karachi, Pakistan",Pending
3,Bilal,bilal@example.com,,Islamabad
# ERROR: Connection dropped here during log creation
4,Ayesha,ayesha@example.com,not_an_age,Rawalpindi,Active
5,Zain,zain@example.com,22,Multan,Inactive
6,Fatima,fatima@example.com,28,Faisalabad,Active,ExtraField1,ExtraField2
,,,
7,Umer,umer@example.com,35,Peshawar,Active
"""

def test_parse_messy_csv():
    df = parse_file("messy_test.csv", MESSY_SAMPLE_CSV)
    assert not df.empty
    assert len(df) == 7
    assert list(df.columns) == ["id", "name", "email", "age", "city", "status"]
    # Check that Ali is row 0
    assert df.iloc[0]["name"] == "Ali Ahmed"
    # Check that Bilal has Islamabad as city
    assert df.iloc[2]["city"] == "Islamabad"
    # Check that Fatima is parsed despite extra fields
    assert df.iloc[5]["name"] == "Fatima"
    # Check that Umer is row 6
    assert df.iloc[6]["name"] == "Umer"

def test_analyze_messy_dataframe():
    df = parse_file("messy_test.csv", MESSY_SAMPLE_CSV)
    analysis = analyze_dataframe(df)
    assert analysis["total_rows"] == 7
    # Missing values should be detected
    assert len(analysis["missing_by_column"]) > 0

def test_api_upload_messy_csv(client):
    client.post("/auth/register", json={"email": "messy_user@example.com", "password": "password123"})
    login_resp = client.post("/auth/login", json={"email": "messy_user@example.com", "password": "password123"})
    token = login_resp.json()["access_token"]

    response = client.post(
        "/analyze",
        files={"file": ("messy_test.csv", io.BytesIO(MESSY_SAMPLE_CSV), "text/csv")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total_rows"] == 7
    assert "missing_by_column" in data
