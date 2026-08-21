import io
import os
import zipfile
from fastapi import HTTPException, UploadFile, status

MAX_FILE_SIZE_MB = 10
MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024
CHUNK_SIZE_BYTES = 64 * 1024  # 64 KB per chunk

# Maximum uncompressed XML size allowed inside an XLSX zip container (50 MB)
MAX_UNCOMPRESSED_SIZE_BYTES = 50 * 1024 * 1024

# Conservative dataset dimension limits
MAX_DATASET_ROWS = 100_000
MAX_DATASET_COLS = 500

# Magic-byte file signatures
ZIP_MAGIC_BYTES = b"PK\x03\x04"
OLE2_XLS_MAGIC_BYTES = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"


async def read_file_bounded_chunks(file: UploadFile) -> bytes:
    """
    Reads an incoming UploadFile stream in bounded 64KB chunks up to MAX_FILE_SIZE_BYTES.
    Raises an HTTP 413 error immediately if the file size exceeds 10 MB without
    reading the remaining stream into RAM.
    """
    buffer = io.BytesIO()
    total_bytes_read = 0

    while True:
        chunk = await file.read(CHUNK_SIZE_BYTES)
        if not chunk:
            break
        total_bytes_read += len(chunk)
        if total_bytes_read > MAX_FILE_SIZE_BYTES:
            raise HTTPException(
                status_code=413,
                detail=f"File is too large. Maximum allowed size is {MAX_FILE_SIZE_MB}MB.",
            )
        buffer.write(chunk)

    return buffer.getvalue()


def validate_file_format_and_safety(filename: str, contents: bytes) -> str:
    """
    Validates extension, magic-byte signature, and archive safety.
    Returns normalized lower-case extension (e.g. '.csv', '.xlsx', '.xls').
    Raises HTTP 400 Bad Request on format or security validation failure.
    """
    filename_lower = filename.lower()
    
    if filename_lower.endswith('.csv'):
        _validate_csv_contents(contents)
        return '.csv'
    elif filename_lower.endswith('.xlsx'):
        _validate_xlsx_magic_and_zip(contents)
        return '.xlsx'
    elif filename_lower.endswith('.xls'):
        _validate_xls_magic(contents)
        return '.xls'
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only CSV (.csv) and Excel (.xlsx, .xls) files are supported.",
        )


def _validate_csv_contents(contents: bytes):
    """
    Validates CSV file contents. Checks for binary null bytes to detect non-text files.
    """
    if not contents or len(contents.strip()) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The uploaded CSV file is empty.",
        )
    # Check for binary null bytes (indicates non-text binary file renamed to .csv)
    if b"\x00" in contents[:4096]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid CSV file. File contains binary data.",
        )


def _validate_xlsx_magic_and_zip(contents: bytes):
    """
    Verifies XLSX ZIP magic-bytes and inspects ZIP archive container safety (Zip Bomb check).
    """
    if not contents.startswith(ZIP_MAGIC_BYTES):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid XLSX file. Magic-byte signature does not match Office Open XML format.",
        )

    try:
        with zipfile.ZipFile(io.BytesIO(contents)) as zf:
            namelist = zf.namelist()

            # Verify it contains Office Open XML structure
            has_workbook_xml = any(
                f in namelist for f in ["xl/workbook.xml", "[Content_Types].xml", "xl/worksheets/sheet1.xml"]
            )
            if not has_workbook_xml:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid XLSX file. Archive missing required Office Open XML sheets.",
                )

            # Check uncompressed size to prevent Zip Bomb memory expansion
            total_uncompressed = 0
            for info in zf.infolist():
                # Prevent path traversal inside zip file names
                if ".." in info.filename or info.filename.startswith("/") or info.filename.startswith("\\"):
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Invalid XLSX file. Archive contains suspicious relative paths.",
                    )
                total_uncompressed += info.file_size
                if total_uncompressed > MAX_UNCOMPRESSED_SIZE_BYTES:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="XLSX file uncompressed size exceeds maximum safety limit (50MB).",
                    )
    except zipfile.BadZipFile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or corrupted XLSX file container.",
        )


def _validate_xls_magic(contents: bytes):
    """
    Verifies legacy XLS OLE2 Compound Document magic-bytes.
    """
    if not contents.startswith(OLE2_XLS_MAGIC_BYTES):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid XLS file. Magic-byte signature does not match OLE2 format.",
        )
