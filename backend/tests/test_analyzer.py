import pytest
import pandas as pd
import numpy as np
from app.services.analyzer import analyze_dataframe, find_missing_data, find_duplicate_rows

def test_analyze_empty_dataframe():
    df = pd.DataFrame()
    with pytest.raises(ValueError, match="Cannot analyze an empty dataset."):
        analyze_dataframe(df)

def test_find_missing_data():
    df = pd.DataFrame({"A": [1, np.nan, 3], "B": [np.nan, 2, np.nan]})
    result = find_missing_data(df, "A")
    assert result["total_missing"] == 1
    assert len(result["sample_rows"]) == 1
    assert result["sample_rows"][0]["row_number"] == 2

def test_find_duplicate_rows():
    df = pd.DataFrame({"A": [1, 1, 2], "B": [2, 2, 3]})
    result = find_duplicate_rows(df)
    assert result["total_duplicates"] == 2
    assert len(result["sample_rows"]) == 2

def test_analyze_dataframe_full():
    df = pd.DataFrame({"A": [1, np.nan, 1], "B": [2, 2, 2]})
    report = analyze_dataframe(df)
    assert report["total_rows"] == 3
    assert "A" in report["missing_by_column"]
    assert report["duplicates"]["total_duplicates"] == 2
