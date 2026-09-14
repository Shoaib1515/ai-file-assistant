import csv
import io
import pandas as pd
from app.core.validation import MAX_DATASET_ROWS, MAX_DATASET_COLS


def _parse_csv_robust(contents: bytes) -> pd.DataFrame:
    """
    Robust CSV parser that handles:
    1. Multiple character encodings (utf-8, utf-8-sig, latin1, cp1252).
    2. Leading/trailing and embedded comment lines (#, //, ;).
    3. Blank or garbage comma lines (e.g. ',,,').
    4. Auto-detecting real header row.
    5. Mismatched column counts across rows (missing fields padded, extra fields handled).
    """
    # 1. Try standard pandas read_csv first (fast path for clean files)
    try:
        df = pd.read_csv(io.BytesIO(contents))
        if not df.empty and not str(df.columns[0]).startswith('#') and not str(df.columns[0]).startswith('Unnamed:'):
            return df
    except Exception:
        pass

    # 2. Resilient multi-encoding decoding
    text = None
    for enc in ['utf-8-sig', 'utf-8', 'latin1', 'cp1252']:
        try:
            text = contents.decode(enc)
            break
        except Exception:
            continue

    if text is None:
        text = contents.decode('utf-8', errors='replace')

    # 3. Clean lines - remove comments, garbage blank-comma lines
    lines = text.splitlines()
    cleaned_lines = []
    for line in lines:
        s = line.strip()
        if not s:
            continue
        # Skip comment lines
        if s.startswith(('#', '//', '/*')):
            continue
        # Skip lines that are only commas, semicolons, tabs, or spaces
        if set(s).issubset({',', ';', '\t', ' '}):
            continue
        cleaned_lines.append(line)

    if not cleaned_lines:
        raise ValueError("No valid data rows found in this CSV file.")

    # 4. Use python csv.reader to parse
    # Detect delimiter: comma, semicolon, tab
    sample_text = '\n'.join(cleaned_lines[:10])
    delimiter = ','
    try:
        sniffer = csv.Sniffer()
        dialect = sniffer.sniff(sample_text, delimiters=',;\t|')
        delimiter = dialect.delimiter
    except Exception:
        delimiter = ','

    reader = csv.reader(cleaned_lines, delimiter=delimiter)
    all_rows = []
    for row in reader:
        if not row or all(not str(cell).strip() for cell in row):
            continue
        if str(row[0]).strip().startswith(('#', '//')):
            continue
        all_rows.append([str(cell).strip() for cell in row])

    if not all_rows:
        raise ValueError("No valid tabular data found in this CSV file.")

    # First row is header
    raw_header = all_rows[0]
    data_rows = all_rows[1:]

    # Clean header column names
    header = []
    seen = {}
    for i, col in enumerate(raw_header):
        name = col.strip()
        if not name:
            name = f"col_{i+1}"
        if name in seen:
            seen[name] += 1
            name = f"{name}_{seen[name]}"
        else:
            seen[name] = 0
        header.append(name)

    header_len = len(header)
    padded_rows = []
    for r in data_rows:
        if len(r) < header_len:
            r = r + [None] * (header_len - len(r))
        elif len(r) > header_len:
            r = r[:header_len]
        # Replace empty strings with None for proper missing value analysis
        cleaned_r = [None if cell == '' else cell for cell in r]
        padded_rows.append(cleaned_r)

    df = pd.DataFrame(padded_rows, columns=header)
    df = df.dropna(how='all')
    return df


def parse_file(filename: str, contents: bytes) -> pd.DataFrame:
    """
    Parses an uploaded file (CSV or Excel) and returns a Pandas DataFrame.
    Normalizes extensions to lowercase (.csv, .xlsx, .xls) and enforces row/col limits.
    Raises ValueError with a clear user-facing message on any parsing or validation failure.
    """
    filename_lower = filename.lower()

    if filename_lower.endswith('.csv'):
        try:
            df = _parse_csv_robust(contents)
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
