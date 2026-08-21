import pandas as pd
import io
from app.core.validation import MAX_DATASET_ROWS, MAX_DATASET_COLS


def parse_file(filename: str, contents: bytes) -> pd.DataFrame:
    """
    Parses an uploaded file (CSV or Excel) and returns a Pandas DataFrame.
    Normalizes extensions to lowercase (.csv, .xlsx, .xls) and enforces row/col limits.
    Raises ValueError with a clear user-facing message on any parsing or validation failure.
    """
    filename_lower = filename.lower()

    if filename_lower.endswith('.csv'):
        try:
            df = pd.read_csv(io.BytesIO(contents))
        except Exception as e:
            raise ValueError(f"Could not read this CSV file: {str(e)}")
    elif filename_lower.endswith('.xlsx'):
        try:
            df = pd.read_excel(io.BytesIO(contents), engine='openpyxl')
        except Exception as e:
            raise ValueError(f"Could not read this XLSX file: {str(e)}")
    elif filename_lower.endswith('.xls'):
        try:
            df = pd.read_excel(io.BytesIO(contents), engine='xlrd')
        except Exception as e:
            raise ValueError(f"Could not read this legacy XLS file: {str(e)}")
    else:
        raise ValueError("Only CSV (.csv) and Excel (.xlsx, .xls) files are supported.")

    if df.empty:
        raise ValueError("The file appears to be empty.")

    if len(df) > MAX_DATASET_ROWS:
        raise ValueError(
            f"Dataset row count ({len(df):,}) exceeds maximum allowed limit of {MAX_DATASET_ROWS:,} rows."
        )

    if len(df.columns) > MAX_DATASET_COLS:
        raise ValueError(
            f"Dataset column count ({len(df.columns):,}) exceeds maximum allowed limit of {MAX_DATASET_COLS:,} columns."
        )

    return df


def get_file_summary(df: pd.DataFrame) -> dict:
    return {
        "total_rows": len(df),
        "total_columns": len(df.columns),
        "columns": list(df.columns),
        "missing_values": df.isnull().sum().to_dict(),
    }
