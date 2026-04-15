from __future__ import annotations

import secrets

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials, OAuth2PasswordBearer

from .config import settings
from .db import apply_due_pending_worker_plan, get_worker
from .phone import normalize_phone_number
from .security import decode_access_token, verify_password

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/verify-otp")
admin_basic = HTTPBasic(auto_error=False)


async def get_current_phone(token: str = Depends(oauth2_scheme)) -> str:
    return normalize_phone_number(decode_access_token(token))


async def get_current_worker(phone: str = Depends(get_current_phone)) -> dict:
    await apply_due_pending_worker_plan(phone)
    worker = await get_worker(phone)
    if not worker:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Worker not found for token subject",
        )
    return worker


async def get_admin_actor(credentials: HTTPBasicCredentials | None = Depends(admin_basic)) -> str:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin authentication required",
            headers={"WWW-Authenticate": "Basic"},
        )
    username_ok = secrets.compare_digest(credentials.username, settings.admin_username)
    password_ok = verify_password(credentials.password, settings.admin_password)
    if not (username_ok and password_ok):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username
