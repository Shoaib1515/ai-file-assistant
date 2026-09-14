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


def test_multisheet_excel_parsing():
    from app.services.file_parser import parse_file, get_sheet_names

    buffer = io.BytesIO()
    with pd.ExcelWriter(buffer, engine='openpyxl') as writer:
        pd.DataFrame({"Sales": [100, 200]}).to_excel(writer, sheet_name="SalesSheet", index=False)
        pd.DataFrame({"Expenses": [50, 75]}).to_excel(writer, sheet_name="ExpensesSheet", index=False)

    excel_bytes = buffer.getvalue()
    sheet_names = get_sheet_names("test.xlsx", excel_bytes)
    assert sheet_names == ["SalesSheet", "ExpensesSheet"]

    # Parse sheet 1
    df_sales = parse_file("test.xlsx", excel_bytes, sheet_name="SalesSheet")
    assert "Sales" in df_sales.columns
    assert len(df_sales) == 2

    # Parse sheet 2
    df_expenses = parse_file("test.xlsx", excel_bytes, sheet_name="ExpensesSheet")
    assert "Expenses" in df_expenses.columns
    assert len(df_expenses) == 2
