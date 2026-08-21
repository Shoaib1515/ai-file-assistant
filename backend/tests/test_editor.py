import pytest
import io
import pandas as pd
import json
from app.services.editor import apply_changes

def test_apply_changes_basic():
    df = pd.DataFrame({"A": [1, 2], "B": [3, 4]})
    changes = [{"row_number": 1, "column": "A", "new_value": "100"}]
    updated_df = apply_changes(df.copy(), changes)
    assert updated_df.at[0, "A"] == "100"
    assert updated_df.at[1, "A"] == 2

def test_apply_changes_column_widen():
    df = pd.DataFrame({"A": [100, 200]})
    # "0123" should trigger column widening
    changes = [{"row_number": 1, "column": "A", "new_value": "0123"}]
    updated_df = apply_changes(df.copy(), changes)
    # Row 0 should be "0123", Row 1 should be "200" (converted)
    assert updated_df.at[0, "A"] == "0123"
    assert updated_df.at[1, "A"] == "200"

def test_apply_changes_invalid_row():
    df = pd.DataFrame({"A": [1]})
    changes = [{"row_number": 10, "column": "A", "new_value": "100"}]
    updated_df = apply_changes(df.copy(), changes)
    pd.testing.assert_frame_equal(updated_df, df)

def test_apply_changes_invalid_column():
    df = pd.DataFrame({"A": [1]})
    changes = [{"row_number": 1, "column": "C", "new_value": "100"}]
    updated_df = apply_changes(df.copy(), changes)
    pd.testing.assert_frame_equal(updated_df, df)
