import os
import json
import base64
import hmac
import hashlib
import time
import secrets
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.models.user import User

DEFAULT_SECRET = "ai-file-assistant-secret-key-2026-change-in-production"
SECRET_KEY = os.getenv("JWT_SECRET_KEY") or "dev-secret-key-change-in-production"
if os.getenv("APP_ENV") == "production" and (not os.getenv("JWT_SECRET_KEY") or SECRET_KEY == DEFAULT_SECRET):
    raise RuntimeError("JWT_SECRET_KEY environment variable MUST be configured with a secure value in production.")
security = HTTPBearer()


def get_password_hash(password: str, salt: Optional[str] = None) -> str:
    """
    Hashes a password using PBKDF2-HMAC-SHA256 with 100,000 iterations and a random salt.
    """
    if not salt:
        salt = secrets.token_hex(16)
    hashed = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 100000).hex()
    return f"{salt}${hashed}"


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verifies a plain password against a stored salt$hash string.
    """
    try:
        salt, _ = hashed_password.split('$')
        return get_password_hash(plain_password, salt) == hashed_password
    except Exception:
        return False


def create_access_token(data: dict, expires_in_seconds: int = 604800) -> str:
    """
    Generates an HMAC-SHA256 signed JWT access token.
    Default expiration is 7 days (604800 seconds).
    """
    header = {"alg": "HS256", "typ": "JWT"}
    payload = dict(data)
    payload["exp"] = int(time.time()) + expires_in_seconds

    def b64url(b: bytes) -> str:
        return base64.urlsafe_b64encode(b).rstrip(b'=').decode('utf-8')

    enc_h = b64url(json.dumps(header).encode('utf-8'))
    enc_p = b64url(json.dumps(payload).encode('utf-8'))
    signing_input = f"{enc_h}.{enc_p}"
    sig = hmac.new(SECRET_KEY.encode('utf-8'), signing_input.encode('utf-8'), hashlib.sha256).digest()
    return f"{signing_input}.{b64url(sig)}"


def decode_access_token(token: str) -> dict:
    """
    Decodes and verifies an HMAC-SHA256 JWT access token.
    Raises ValueError if format, signature, or expiration is invalid.
    """
    parts = token.split('.')
    if len(parts) != 3:
        raise ValueError("Invalid token format")
    enc_h, enc_p, enc_sig = parts
    signing_input = f"{enc_h}.{enc_p}"

    def b64url(b: bytes) -> str:
        return base64.urlsafe_b64encode(b).rstrip(b'=').decode('utf-8')

    def b64url_dec(s: str) -> bytes:
        rem = len(s) % 4
        if rem > 0:
            s += '=' * (4 - rem)
        return base64.urlsafe_b64decode(s)

    expected_sig = b64url(hmac.new(SECRET_KEY.encode('utf-8'), signing_input.encode('utf-8'), hashlib.sha256).digest())
    if not hmac.compare_digest(enc_sig, expected_sig):
        raise ValueError("Invalid signature")

    payload = json.loads(b64url_dec(enc_p).decode('utf-8'))
    if "exp" in payload and time.time() > payload["exp"]:
        raise ValueError("Token has expired")
    return payload


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    FastAPI dependency that extracts and validates the Bearer JWT token from the
    Authorization header, returning the authenticated User object.
    Raises HTTP 401 if invalid or user not found.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    token = credentials.credentials
    try:
        payload = decode_access_token(token)
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except Exception:
        raise credentials_exception

    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise credentials_exception
    return user
