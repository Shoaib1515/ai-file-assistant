import re
import pandas as pd
import numpy as np
from app.services.analyzer import MISSING_PLACEHOLDERS, analyze_dataframe


def clean_column_name(col_name: str) -> str:
    """Normalize and format messy column names into clean human-readable Title Case."""
    if not isinstance(col_name, str):
        col_name = str(col_name)
    
    # Check for generic unnamed or col_0 columns
    if re.match(r"^(unnamed:\s*|col_?|column_?)\d+$", col_name.strip(), re.IGNORECASE):
        match = re.search(r"\d+", col_name)
        num = int(match.group()) + 1 if match else 1
        return f"Column {num}"
    
    # Replace separators with single space
    cleaned = re.sub(r"[_\-\.]+", " ", col_name)
    # Split camelCase into words (e.g., 'firstName' -> 'first Name')
    cleaned = re.sub(r"([a-z])([A-Z])", r"\1 \2", cleaned)
    # Remove unwanted special characters except standard alphanumeric and spaces
    cleaned = re.sub(r"[^\w\s]", "", cleaned)
    # Strip extra spaces and title case
    cleaned = " ".join(cleaned.split()).strip().title()
    
    # Common short abbreviations expansion
    abbreviations = {
        "Id": "ID",
        "No": "Number",
        "Num": "Number",
        "Qty": "Quantity",
        "Amt": "Amount",
        "Usr": "User",
        "Nm": "Name",
        "Emp": "Employee",
        "Cust": "Customer",
        "Addr": "Address",
        "Desc": "Description",
        "Msg": "Message",
        "Dob": "Date Of Birth",
        "Ph": "Phone",
        "Tel": "Telephone",
    }
    words = cleaned.split()
    expanded_words = [abbreviations.get(w, w) for w in words]
    return " ".join(expanded_words) if expanded_words else col_name


def is_email_column(series: pd.Series) -> bool:
    """Check if series looks like an email address column."""
    sample = series.dropna().astype(str).head(50)
    if sample.empty:
        return False
    email_regex = re.compile(r"^[\w\.\+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z0-9\-\.]+$")
    match_count = sum(1 for val in sample if email_regex.match(val.strip()))
    return (match_count / len(sample)) >= 0.5


def is_date_column(series: pd.Series) -> bool:
    """Check if series can be cleanly converted to dates."""
    sample = series.dropna().astype(str).head(30)
    if sample.empty:
        return False
    # Don't treat simple integers/numbers as dates
    if pd.api.types.is_numeric_dtype(series):
        return False
    
    valid_dates = 0
    for val in sample:
        val_str = val.strip()
        if re.search(r"[\/\-\.]\d{2,4}", val_str) or re.search(r"\d{4}[\/\-\.]", val_str):
            try:
                pd.to_datetime(val_str, errors='raise', format='mixed')
                valid_dates += 1
            except Exception:
                pass
    return (valid_dates / len(sample)) >= 0.6


def auto_structure_dataframe(df: pd.DataFrame, filename: str = "") -> dict:
    """
    Autonomous AI & Statistical Data Structuring Engine:
    1. Header normalization & cleaning.
    2. Placeholder & missing data imputation.
    3. Type coercion & corrupted value fix.
    4. Text trimming & formatting standardization.
    5. ISO Date normalization.
    6. Deduplication.
    7. Before vs After comparison metrics.
    """
    initial_analysis = analyze_dataframe(df)
    initial_score = initial_analysis.get("health_score", 100)
    
    cleaned_df = df.copy()
    
    # 1. Deduplicate rows
    initial_rows = len(cleaned_df)
    cleaned_df = cleaned_df.drop_duplicates()
    duplicates_removed = initial_rows - len(cleaned_df)
    
    # 2. Normalize and Rename Column Headers
    columns_renamed = []
    new_cols = {}
    seen_names = {}
    for col in cleaned_df.columns:
        clean_name = clean_column_name(col)
        # Handle duplicate resulting column names
        if clean_name in seen_names:
            seen_names[clean_name] += 1
            clean_name = f"{clean_name} {seen_names[clean_name]}"
        else:
            seen_names[clean_name] = 1
        
        if clean_name != str(col):
            columns_renamed.append({"old": str(col), "new": clean_name})
        new_cols[col] = clean_name
        
    cleaned_df = cleaned_df.rename(columns=new_cols)
    
    placeholders_cleaned = 0
    types_fixed = 0
    whitespace_trimmed = 0
    
    # 3. Clean and Standardize Data in each column
    for col in cleaned_df.columns:
        series = cleaned_df[col]
        
        # Check string columns for placeholders & whitespace
        if series.dtype == object or isinstance(series.dtype, pd.StringDtype):
            # Trim whitespace
            original_strs = series.dropna().astype(str)
            trimmed_strs = original_strs.str.strip()
            diff_count = (original_strs != trimmed_strs).sum()
            whitespace_trimmed += int(diff_count)
            
            # Identify placeholders
            is_placeholder = series.astype(str).str.strip().str.lower().isin(MISSING_PLACEHOLDERS)
            p_count = int(is_placeholder.sum())
            placeholders_cleaned += p_count
            
            # Replace placeholders with clean NaN
            series = series.mask(is_placeholder, np.nan)
            series = series.apply(lambda x: x.strip() if isinstance(x, str) else x)
            
            # Check if column is predominantly numeric with some corrupted string anomalies
            coerced_numeric = pd.to_numeric(series, errors='coerce')
            valid_numeric_count = coerced_numeric.notna().sum()
            total_non_na = series.notna().sum()
            
            if total_non_na > 0 and (valid_numeric_count / total_non_na) >= 0.6 and not is_date_column(series):
                # Fix corrupted non-numeric values
                corrupted_mask = series.notna() & coerced_numeric.isna()
                corrupted_count = int(corrupted_mask.sum())
                if corrupted_count > 0:
                    types_fixed += corrupted_count
                    # Fill corrupted / missing with median or rounded mean if available
                    median_val = coerced_numeric.median()
                    if pd.isna(median_val):
                        median_val = 0
                    if (coerced_numeric.dropna() % 1 == 0).all():
                        median_val = int(median_val)
                    series = coerced_numeric.fillna(median_val)
                else:
                    # Cleanly convert to numeric
                    series = coerced_numeric
            
            # Check if column is an Email column
            elif is_email_column(series):
                series = series.apply(lambda x: str(x).lower().strip() if pd.notna(x) else x)
                
            # Check if column is a Date column
            elif is_date_column(series):
                try:
                    parsed_dates = pd.to_datetime(series, errors='coerce', format='mixed')
                    types_fixed += int((series.notna() & parsed_dates.notna()).sum())
                    series = parsed_dates.dt.strftime('%Y-%m-%d')
                except Exception:
                    pass
            
            # Text/Name column normalization (Capitalize title case)
            elif "name" in col.lower() or "city" in col.lower() or "country" in col.lower():
                series = series.apply(lambda x: str(x).title().strip() if pd.notna(x) else x)
        
        cleaned_df[col] = series
    
    # 4. Final Analysis on Cleaned Structured Dataset
    final_analysis = analyze_dataframe(cleaned_df)
    structured_score = final_analysis.get("health_score", 100)
    
    # Prepare sample preview rows
    sample_records = cleaned_df.head(25).fillna("").to_dict(orient="records")
    clean_csv_string = cleaned_df.to_csv(index=False)
    
    return {
        "filename": filename,
        "initial_health_score": round(float(initial_score), 1),
        "structured_health_score": round(float(structured_score), 1),
        "total_rows": len(cleaned_df),
        "total_columns": len(cleaned_df.columns),
        "columns_renamed": columns_renamed,
        "placeholders_cleaned": placeholders_cleaned,
        "types_fixed": types_fixed,
        "whitespace_trimmed": whitespace_trimmed,
        "duplicates_removed": duplicates_removed,
        "columns": list(cleaned_df.columns),
        "sample_preview": sample_records,
        "csv_content": clean_csv_string,
        "success": True,
        "message": f"Successfully auto-structured {len(cleaned_df)} rows and {len(cleaned_df.columns)} columns."
    }
