from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.exc import IntegrityError

import crud
from authentication.auth import (CurrentUser, bearer, create_access_token, fetch_clerk_profile, verify_clerk_token)
from database import SessionDep
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field

from authentication.auth import get_current_user
from model import (
    ActivityStatus, BgSoundOption, CaptionColorOption, CaptionFontOption,
    VideoTemplateOption, VoiceOption,
)

router = APIRouter(prefix="/user", tags=["scrolz-api"])


@router.post("/session")
def create_session(session: SessionDep, creds: HTTPAuthorizationCredentials = Depends(bearer)):
    """Send the Clerk session token as the Bearer token. Returns your own JWT."""
    if creds is None:
        raise HTTPException(401, "Missing Clerk token")
    clerk_id = verify_clerk_token(creds.credentials)["sub"]

    user = crud.get_user_by_clerk_id(session, clerk_id)
    if not user:
        profile = fetch_clerk_profile(clerk_id)
        existing = crud.get_user_by_email(session, profile["email"])
        try:
            if existing and not existing.clerk_id:  # row made before Clerk: link it
                existing.clerk_id = clerk_id
                existing.username = existing.username or profile["username"]
                session.add(existing)
                session.commit()
                session.refresh(existing)
                user = existing
            else:
                user = crud.create_user(session, clerk_id, profile["email"], profile["username"])
        except IntegrityError:  # two requests raced; the other one won
            session.rollback()
            user = crud.get_user_by_clerk_id(session, clerk_id)

    return {
        "token": create_access_token(user.id),
        "token_type": "bearer",
        "user": {"id": user.id, "email": user.email, "username": user.username},
    }


@router.get("/me")
def me(session: SessionDep, user_id: CurrentUser):
    user = crud.get_user(session, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    return {"id": user.id, "email": user.email, "username": user.username}



# router = APIRouter(...) stays as you already have it


# ---------- schemas ----------
class SettingsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    voice: VoiceOption
    bg_sound: BgSoundOption
    bg_color: str
    caption_font: CaptionFontOption
    caption_color: CaptionColorOption
    caption_size: int
    video_template: VideoTemplateOption


class SettingsUpdate(BaseModel):
    voice: Optional[VoiceOption] = None
    bg_sound: Optional[BgSoundOption] = None
    bg_color: Optional[str] = Field(default=None, pattern=r"^#[0-9a-fA-F]{6}$")
    caption_font: Optional[CaptionFontOption] = None
    caption_color: Optional[CaptionColorOption] = None
    caption_size: Optional[int] = Field(default=None, ge=8, le=72)
    video_template: Optional[VideoTemplateOption] = None


class BillingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    token_balance: int
    auto_billing_enabled: bool
    updated_at: datetime


class ActivityOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    action: str
    created_at: datetime
    status: ActivityStatus


# ---------- endpoints ----------
@router.get("/settings", response_model=SettingsOut)
def get_settings(session: SessionDep, user_id: int = Depends(get_current_user)):
    return crud.get_or_create_user_settings(session, user_id)


@router.put("/update/settings", response_model=SettingsOut)
def update_settings(
    payload: SettingsUpdate,
    session: SessionDep,
    user_id: int = Depends(get_current_user),
):
    settings = crud.get_or_create_user_settings(session, user_id)
    ok, updated = crud.update_data(
        "settings", settings.id, payload.model_dump(exclude_none=True), session
    )
    if not ok:
        raise HTTPException(status_code=404, detail="Settings not found")
    return updated


@router.get("/activity", response_model=List[ActivityOut])
def get_activities(
    session: SessionDep,
    user_id: int = Depends(get_current_user),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    return crud.list_user_activities(session, user_id, limit, offset)


@router.get("/billing", response_model=BillingOut)
def get_billing(session: SessionDep, user_id: int = Depends(get_current_user)):
    return crud.get_or_create_user_billing(session, user_id)
