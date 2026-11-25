from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
import requests
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient

from config import CLERK_ISSUER, CLERK_SECRET_KEY, JWT_EXPIRE_MINUTES, JWT_SECRET

if not (JWT_SECRET and CLERK_SECRET_KEY and CLERK_ISSUER):
    raise RuntimeError("Set JWT_SECRET, CLERK_SECRET_KEY and CLERK_ISSUER in .env")

ALGORITHM = "HS256"
bearer = HTTPBearer(auto_error=False)
_jwks = PyJWKClient(f"{CLERK_ISSUER}/.well-known/jwks.json", cache_keys=True)

_401 = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


# ---------- Clerk side (used once, at login) ----------
def verify_clerk_token(token: str) -> dict:
    """Check the signature, expiry and issuer of a Clerk session token."""
    try:
        key = _jwks.get_signing_key_from_jwt(token).key
        return jwt.decode(
            token, key, algorithms=["RS256"], issuer=CLERK_ISSUER, leeway=10,
            options={"require": ["exp", "sub", "iss"], "verify_aud": False},
        )
    except jwt.PyJWTError:
        raise _401


def fetch_clerk_profile(clerk_id: str) -> dict:
    """Ask Clerk for the user's email and username (trusted, unlike client input)."""
    r = requests.get(
        f"https://api.clerk.com/v1/users/{clerk_id}",
        headers={"Authorization": f"Bearer {CLERK_SECRET_KEY}"},
        timeout=10,
    )
    if r.status_code != 200:
        raise HTTPException(502, "Could not fetch user from Clerk")
    data = r.json()
    primary = data.get("primary_email_address_id")
    emails = data.get("email_addresses") or []
    email = next((e["email_address"] for e in emails if e["id"] == primary),
                 emails[0]["email_address"] if emails else None)
    if not email:
        raise HTTPException(400, "Clerk user has no email address")
    return {"email": email, "username": data.get("username") or email.split("@")[0]}


# ---------- your own token (used on every request) ----------
def create_access_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=JWT_EXPIRE_MINUTES)
    return jwt.encode({"sub": str(user_id), "exp": expire}, JWT_SECRET, algorithm=ALGORITHM)


def get_current_user(creds: HTTPAuthorizationCredentials | None = Depends(bearer)) -> int:
    """Returns user_id (int) from your own JWT."""
    if creds is None:
        raise _401
    try:
        payload = jwt.decode(creds.credentials, JWT_SECRET, algorithms=[ALGORITHM])
        return int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise _401


CurrentUser = Annotated[int, Depends(get_current_user)]