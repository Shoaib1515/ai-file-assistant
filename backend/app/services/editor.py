import pandas as pd
import io

def sanitize_cell_value(val):
    """
    Prevents CSV/Excel formula injection by prepending a single quote (')
    to non-numeric string values starting with dangerous formula characters (=, +, -, @, \t, \r).
    Preserves non-string values (int, float, bool, None), numeric strings, and safe text.
    """
    if not isinstance(val, str):
        return val
    try:
        float(val)
        return val
    except ValueError:
        pass

    if val.startswith(('=', '+', '-', '@', '\t', '\r')):
        return "'" + val
    return val


def apply_changes(df: pd.DataFrame, changes: list) -> pd.DataFrame:
    """
    Applies a list of approved cell-level changes to the DataFrame.
    Row numbers are 1-indexed (as shown to the user), so we convert
    back to 0-indexed for Pandas.

    If any change requires a column to become text (e.g. a phone
    number with a leading zero), the ENTIRE column is converted to
    text — not just the edited cell — so every value in that column
    displays consistently (avoids one row looking "different" from
    the rest, as with numbers vs text alignment in Excel).
    """
    columns_to_widen = set()

    # First pass: figure out which columns need to become text
    for change in changes:
        column = change["column"]
        new_value = change["new_value"]
        if isinstance(new_value, str) and not new_value.replace('.', '', 1).isdigit():
            continue  # genuinely non-numeric text, no special handling needed
        if isinstance(new_value, str) and (new_value.startswith('0') or len(new_value) > 9):
            columns_to_widen.add(column)

    # Convert whole columns to text where needed, so all rows match
    for column in columns_to_widen:
        if column in df.columns:
            df[column] = df[column].apply(
                lambda x: str(int(x)) if pd.notna(x) and isinstance(x, (int, float)) else x
            )
            df[column] = df[column].astype(object)

    # Second pass: apply the actual changes
    for change in changes:
        row_index = change["row_number"] - 1
        column = change["column"]
        raw_value = change["new_value"]
        new_value = sanitize_cell_value(raw_value)

        if row_index in df.index and column in df.columns:
            try:
                df.at[row_index, column] = new_value
            except (TypeError, ValueError):
                df[column] = df[column].astype(object)
                df.at[row_index, column] = new_value
    return df


def dataframe_to_excel_bytes(df: pd.DataFrame) -> bytes:
    output = io.BytesIO()
    df.to_excel(output, index=False, engine='openpyxl')
    output.seek(0)
    return output.read()