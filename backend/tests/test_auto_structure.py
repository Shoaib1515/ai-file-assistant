import io
import pandas as pd
from app.services.auto_structurer import clean_column_name, auto_structure_dataframe


def test_clean_column_name():
    assert clean_column_name("col_0") == "Column 1"
    assert clean_column_name("usr_nm") == "User Name"
    assert clean_column_name("emp_id") == "Employee ID"
    assert clean_column_name("first_name") == "First Name"
    assert clean_column_name("date_of_birth") == "Date Of Birth"


def test_auto_structure_dataframe_messy():
    raw_data = {
        "col_0": [1, 2, 3, 1],
        "usr_nm": ["  ali khan  ", "bilal ahmed", "ayesha malik", "  ali khan  "],  # duplicate row + whitespace
        "user_age": ["25", "N/A", "not_an_age", "25"],  # placeholder + type mismatch
        "user_email": ["ALI@GMAIL.COM", "bilal@TEST.com", "ayesha@demo.COM", "ALI@GMAIL.COM"],
        "join_date": ["2024/01/15", "15-02-2024", "2024-03-20", "2024/01/15"],
    }
    df = pd.DataFrame(raw_data)
    
    result = auto_structure_dataframe(df, filename="messy.csv")
    
    assert result["success"] is True
    assert result["total_rows"] == 3  # Duplicate row removed
    assert result["duplicates_removed"] == 1
    assert result["placeholders_cleaned"] >= 1
    assert result["types_fixed"] >= 1
    assert result["whitespace_trimmed"] >= 1
    assert result["structured_health_score"] >= result["initial_health_score"]
    
    # Check cleaned column headers
    assert "User Name" in result["columns"]
    assert "User Age" in result["columns"]
    assert "User Email" in result["columns"]
