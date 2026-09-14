import pandas as pd
import numpy as np

MAX_ROWS_PER_ISSUE = 20

MISSING_PLACEHOLDERS = {'', 'n/a', 'na', 'null', 'none', 'nan', '-', '?', 'nil', 'undefined'}


def clean_row_data(row_dict: dict) -> dict:
    """
    Replaces any NaN/None values with None, since NaN is not valid JSON
    but None (JSON null) is.
    """
    return {
        key: (None if value is None or (isinstance(value, float) and np.isnan(value)) else str(value))
        for key, value in row_dict.items()
    }


def find_missing_data(df: pd.DataFrame, column: str) -> dict:
    """
    Returns the total count of missing or placeholder values in a column,
    plus a small sample of affected rows (capped at MAX_ROWS_PER_ISSUE).
    """
    # Check both true nulls and string placeholders (e.g. 'N/A', 'null', '-', etc.)
    is_null_mask = df[column].isnull()
    is_placeholder_mask = df[column].astype(str).str.strip().str.lower().isin(MISSING_PLACEHOLDERS)
    missing_mask = is_null_mask | is_placeholder_mask

    missing_rows = df[missing_mask]
    total_missing = len(missing_rows)

    sample_df = missing_rows.head(MAX_ROWS_PER_ISSUE)
    sample = [
        {"row_number": int(idx) + 1, "data": clean_row_data(row)}
        for idx, row in zip(sample_df.index, sample_df.to_dict('records'))
    ]

    return {
        "total_missing": total_missing,
        "sample_rows": sample
    }


def find_type_mismatches(df: pd.DataFrame, column: str) -> dict:
    """
    Identifies invalid or corrupted values in predominantly numeric columns
    (e.g., 'not_an_age' in an age column, or text in a price/salary column).
    """
    # Filter out nulls and placeholders first
    is_null_mask = df[column].isnull() | df[column].astype(str).str.strip().str.lower().isin(MISSING_PLACEHOLDERS)
    valid_series = df.loc[~is_null_mask, column]

    if valid_series.empty:
        return {"total_mismatches": 0, "sample_rows": []}

    # Test numeric conversion
    numeric_series = pd.to_numeric(valid_series, errors='coerce')
    numeric_count = numeric_series.notnull().sum()
    total_valid = len(valid_series)

    # If column is predominantly numeric (>= 50% numbers) but has non-numeric garbage
    if numeric_count > 0 and (numeric_count / total_valid) >= 0.5 and numeric_count < total_valid:
        invalid_mask = (~is_null_mask) & (pd.to_numeric(df[column], errors='coerce').isnull())
        invalid_rows = df[invalid_mask]
        sample_df = invalid_rows.head(MAX_ROWS_PER_ISSUE)
        sample = [
            {
                "row_number": int(idx) + 1,
                "data": clean_row_data(row),
                "invalid_value": str(row[column]),
                "expected": "Numeric Number"
            }
            for idx, row in zip(sample_df.index, sample_df.to_dict('records'))
        ]
        return {
            "total_mismatches": len(invalid_rows),
            "expected_type": "Numeric",
            "sample_rows": sample
        }

    return {"total_mismatches": 0, "sample_rows": []}


def find_duplicate_rows(df: pd.DataFrame) -> dict:
    """
    Returns the total count of duplicate rows, plus a small sample
    (capped at MAX_ROWS_PER_ISSUE).
    """
    duplicated_mask = df.duplicated(keep=False)
    duplicate_rows = df[duplicated_mask]
    total_duplicates = len(duplicate_rows)

    sample_df = duplicate_rows.head(MAX_ROWS_PER_ISSUE)
    sample = [
        {"row_number": int(idx) + 1, "data": clean_row_data(row)}
        for idx, row in zip(sample_df.index, sample_df.to_dict('records'))
    ]

    return {
        "total_duplicates": total_duplicates,
        "sample_rows": sample
    }


def analyze_dataframe(df: pd.DataFrame) -> dict:
    """
    Runs comprehensive data quality checks on the DataFrame:
    1. Missing & placeholder values per column.
    2. Data type mismatches & format anomalies.
    3. Duplicate rows.
    4. Computes realistic, multi-factor Data Quality Health Score (0 - 100%).
    """
    if df.empty:
        raise ValueError("Cannot analyze an empty dataset.")

    missing_by_column = {}
    type_mismatches_by_column = {}
    total_missing_cells = 0
    total_mismatch_cells = 0

    for column in df.columns:
        missing_res = find_missing_data(df, column)
        if missing_res["total_missing"] > 0:
            missing_by_column[column] = missing_res
            total_missing_cells += missing_res["total_missing"]

        mismatch_res = find_type_mismatches(df, column)
        if mismatch_res["total_mismatches"] > 0:
            type_mismatches_by_column[column] = mismatch_res
            total_mismatch_cells += mismatch_res["total_mismatches"]

    duplicates = find_duplicate_rows(df)
    total_duplicates = duplicates["total_duplicates"]

    total_rows = len(df)
    total_cols = len(df.columns)
    total_cells = total_rows * total_cols

    # Calculate Data Quality / Health Score (0 - 100%)
    # Penalties:
    # - Missing values impact completeness
    # - Type mismatches / corrupted values impact validity
    # - Duplicates impact uniqueness
    missing_penalty = (total_missing_cells / total_cells * 100) * 1.5 if total_cells > 0 else 0
    mismatch_penalty = (total_mismatch_cells / total_cells * 100) * 2.5 if total_cells > 0 else 0
    duplicate_penalty = (total_duplicates / total_rows * 100) * 0.5 if total_rows > 0 else 0

    # Ensure clean files get 100%, and messy files get proportional deductions
    total_deduction = missing_penalty + mismatch_penalty + duplicate_penalty
    if total_missing_cells > 0 or total_mismatch_cells > 0 or total_duplicates > 0:
        # Minimum baseline deduction if any issue exists
        total_deduction = max(total_deduction, 5.0)

    health_score = max(0.0, min(100.0, 100.0 - total_deduction))
    health_score = round(health_score, 1)

    return {
        "total_rows": total_rows,
        "total_cols": total_cols,
        "total_columns": total_cols,
        "health_score": health_score,
        "total_missing_cells": total_missing_cells,
        "total_mismatch_cells": total_mismatch_cells,
        "missing_by_column": missing_by_column,
        "type_mismatches_by_column": type_mismatches_by_column,
        "duplicates": duplicates
    }