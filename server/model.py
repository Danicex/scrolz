from datetime import datetime, timezone
from typing import List, Optional
from enum import Enum

from sqlmodel import JSON, Column, Field, Relationship, SQLModel, UniqueConstraint


def now():
    return datetime.now(timezone.utc)




class VoiceOption(str, Enum):
    VOICE_1 = "voice_1"
    VOICE_2 = "voice_2"
    VOICE_3 = "voice_3"
    VOICE_4 = "voice_4"
    VOICE_5 = "voice_5"


class BgSoundOption(str, Enum):
    SOUND_1 = "sound_1"
    SOUND_2 = "sound_2"
    SOUND_3 = "sound_3"
    SOUND_4 = "sound_4"
    SOUND_5 = "sound_5"


class CaptionFontOption(str, Enum):
    FONT_1 = "font_1"
    FONT_2 = "font_2"
    FONT_3 = "font_3"
    FONT_4 = "font_4"
    FONT_5 = "font_5"


class CaptionColorOption(str, Enum):
    COLOR_1 = "color_1"
    COLOR_2 = "color_2"
    COLOR_3 = "color_3"
    COLOR_4 = "color_4"
    COLOR_5 = "color_5"
    COLOR_6 = "color_6"
    COLOR_7 = "color_7"


class VideoTemplateOption(str, Enum):
    TEMPLATE_1 = "video_tmplt_1"
    TEMPLATE_2 = "video_tmplt_2"
    TEMPLATE_3 = "video_tmplt_3"


class ActivityStatus(str, Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"


class User(SQLModel, table=True):
    __tablename__ = "users"

    id: Optional[int] = Field(default=None, primary_key=True)
    clerk_id: Optional[str] = Field(default=None, unique=True, index=True)
    email: str = Field(unique=True, index=True)
    username: Optional[str] = None
    created_at: datetime = Field(default_factory=now)

    # Relationships
    settings: Optional["UserSettings"] = Relationship(
        back_populates="user", sa_relationship_kwargs={"uselist": False}
    )
    billing: Optional["UserBilling"] = Relationship(
        back_populates="user", sa_relationship_kwargs={"uselist": False}
    )
    activities: List["UserActivity"] = Relationship(back_populates="user")

class UserSettings(SQLModel, table=True):
    __tablename__ = "user_settings"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", unique=True, index=True)

    # Video Settings
    voice: VoiceOption = Field(default=VoiceOption.VOICE_1)
    bg_sound: BgSoundOption = Field(default=BgSoundOption.SOUND_1)
    bg_color: str = Field(default="#000000")  # Hex code

    # Caption Settings
    caption_font: CaptionFontOption = Field(default=CaptionFontOption.FONT_1)
    caption_color: CaptionColorOption = Field(default=CaptionColorOption.COLOR_1)
    caption_size: int = Field(default=16)

    # Template Selection (Frontend maps enum to preview image)
    video_template: VideoTemplateOption = Field(
        default=VideoTemplateOption.TEMPLATE_1
    )

    user: Optional[User] = Relationship(back_populates="settings")

class UserBilling(SQLModel, table=True):
    __tablename__ = "user_billing"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", unique=True, index=True)

    token_balance: int = Field(default=0)
    auto_billing_enabled: bool = Field(default=False)
    updated_at: datetime = Field(default_factory=now)

    user: Optional[User] = Relationship(back_populates="billing")

class UserActivity(SQLModel, table=True):
    __tablename__ = "user_activities"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)

    action: str  # e.g., "Generated Video", "Topped up 500 tokens"
    created_at: datetime = Field(default_factory=now)
    status: ActivityStatus = Field(default=ActivityStatus.COMPLETED)

    user: Optional[User] = Relationship(back_populates="activities")



class Project(SQLModel, table=True):
    __tablename__ = "projects"

    id: Optional[int] = Field(default=None, primary_key=True)
    title: str
    json_path: str
    user_id: int = Field(foreign_key="users.id", index=True)
    cover: Optional[str] = None
    video_path: Optional[str] = None 
    created_at: datetime = Field(default_factory=now)
    updated_at: datetime = Field(default_factory=now)

    chunks: List["Chunk"] = Relationship(back_populates="project")


class Chunk(SQLModel, table=True):
    __tablename__ = "chunks"
    __table_args__ = (UniqueConstraint("project_id", "index", name="uq_chunk_project_index"),)

    id: Optional[int] = Field(default=None, primary_key=True)
    project_id: int = Field(foreign_key="projects.id", index=True)
    index: int  # 1-based, matches "chunk_1", "chunk_2"
    key: str  # "chunk_1", "chunk_2", ...
    text: str
    summarized_text: Optional[str] = None
    audio: Optional[str] = None  
    quiz: List[dict] = Field(default_factory=list, sa_column=Column(JSON))
    project_name: Optional[str] = None  
    video_url: Optional[str] = None
    project: Optional[Project] = Relationship(back_populates="chunks")
    


class Settings(SQLModel, table=True):
    __tablename__ = "settings"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    tts_model: str = Field(default="default")
    aspect_ratio: str = Field(default="16:9")  # Changed to str, adjust if you prefer a float or int
    allow_bg_sound: bool = Field(default=True)
