import pandas as pd
import numpy as np

MAX_ROWS_PER_ISSUE = 20


def clean_row_data(row_dict: dict) -> dict:
    """
    Replaces any NaN values with None, since NaN is not valid JSON
    but None (JSON null) is.
    """
    return {
        key: (None if isinstance(value, float) and np.isnan(value) else value)
        for key, value in row_dict.items()
    }


def find_missing_data(df: pd.DataFrame, column: str) -> dict:
    """
    Returns the total count of missing values in a column, plus a
    small sample of affected rows (capped at MAX_ROWS_PER_ISSUE).
    Uses to_dict('records') instead of iterrows() for better performance
    on larger files.
    """
    missing_rows = df[df[column].isnull()]
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
    Runs all analysis checks on the DataFrame and returns a summary
    report with sampled row data — safe and fast even for large files.
    """
    if df.empty:
        raise ValueError("Cannot analyze an empty dataset.")
    missing_by_column = {}
    for column in df.columns:
        result = find_missing_data(df, column)
        if result["total_missing"] > 0:
            missing_by_column[column] = result

    duplicates = find_duplicate_rows(df)

    return {
        "total_rows": len(df),
        "missing_by_column": missing_by_column,
        "duplicates": duplicates
    }