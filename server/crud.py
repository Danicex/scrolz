import os
from typing import Optional

from sqlmodel import Session, select
from database import SessionDep
from model import Chunk, Project, User, Settings, now
from model import Chunk, Project, User, UserSettings, UserBilling, UserActivity, now

obj_map = {
    "project": Project,
    "chunk": Chunk,
    "user": User,
    "settings": UserSettings,
    "billing": UserBilling,
    "activity": UserActivity,
}
# ---------- user ----------
def get_user_by_clerk_id(session: Session, clerk_id: str):
    return session.exec(select(User).where(User.clerk_id == clerk_id)).first()


def get_user_by_email(session: Session, email: str):
    return session.exec(select(User).where(User.email == email)).first()


def create_user(session: Session, clerk_id: str, email: str, username: Optional[str] = None):
    user = User(clerk_id=clerk_id, email=email, username=username)
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def get_user(session: Session, user_id: int):
    return session.get(User, user_id)


# ---------- project ----------
def create_project(
    session: Session, title: str, json_path: str, user_id: int, cover: Optional[str] = None
) -> Project:
    project = Project(title=title, json_path=json_path, user_id=user_id, cover=cover)
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def get_project(session: Session, project_id: int):
    return session.get(Project, project_id)


def list_projects(session: Session, user_id: int):
    return session.exec(select(Project).where(Project.user_id == user_id)).all()


def update_project(session: Session, project_id: int, title: str):
    project = session.get(Project, project_id)
    if not project:
        return None
    project.title = title
    project.updated_at = now()
    session.add(project)
    session.commit()
    session.refresh(project)
    return project

def update_chunk_vid_path(session: Session, project_id: int, chunk_id: int, path: str):
    project = session.get(Project, project_id)
    chunk = session.get(Chunk, chunk_id)
    if not project and chunk:
        return None
    chunk.video_url = path
    chunk.updated_at = now()
    session.add(chunk)
    session.commit()
    session.refresh(chunk)
    return "sucessfully stored video url"


def set_video_path(session: Session, project_id: int, video_path: str):
    project = session.get(Project, project_id)
    if not project:
        return None
    project.video_path = video_path
    project.updated_at = now()
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def delete_project(session: Session, project_id: int, remove_files: bool = True):
    project = session.get(Project, project_id)
    if not project:
        return False

    # chunks point at the project, so they must go first
    for chunk in session.exec(select(Chunk).where(Chunk.project_id == project_id)).all():
        session.delete(chunk)

    if remove_files and os.path.exists(project.json_path):
        os.remove(project.json_path)


# ---------- chunks ----------
def insert_chunks(session: Session, project_id: int, chunks: dict) -> int:
    """
    chunks = the dict loaded from json_path:
      { "chunk_1": {"text": ..., "summarized_text": ..., "quiz": [...], "audio": ..., "project_name": ...}, ... }
    """
    # idempotency: skip if already inserted
    existing = session.exec(select(Chunk).where(Chunk.project_id == project_id)).first()
    if existing:
        return 0

    count = 0
    for idx, (key, chunk) in enumerate(chunks.items(), start=1):
        session.add(
            Chunk(
                project_id=project_id,
                index=idx,
                key=key,
                text=chunk.get("text", ""),
                summarized_text=chunk.get("summarized_text"),
                audio=chunk.get("audio"),
                quiz=chunk.get("quiz", []),
                project_name=chunk.get("project_name"),
            )
        )
        count += 1

    session.commit()
    return count

def get_project_chunks(session, project_id):
    return session.exec(select(Chunk).where(Chunk.project_id == project_id)).all()

def read_object(obj_name: str, session: SessionDep, limit: int = 100):
    """
    Read multiple records with rate limit
    """
    model_class = obj_map.get(obj_name.lower())
    if not model_class:
        return None
    
    data = session.exec(
        select(model_class).limit(limit)
    ).all()
    return data

def create_data(obj_name: str, data_obj, session):
    """
    Create a new record
    """
    model_class = obj_map.get(obj_name.lower())
    if not model_class:
        return False, None
    
    instance = model_class(**data_obj.dict() if hasattr(data_obj, 'dict') else data_obj)
    session.add(instance)
    session.commit()
    session.refresh(instance)
    return True, instance

def update_data(obj_name: str, obj_id: int, data_obj, session: SessionDep):
    """
    Update an existing record
    """
    model_class = obj_map.get(obj_name.lower())
    if not model_class:
        return False, None
    
    existing = session.exec(
        select(model_class).where(model_class.id == obj_id)
    ).first()
    
    if not existing:
        return False, None
    
    update_data = data_obj.dict() if hasattr(data_obj, 'dict') else data_obj
    for key, value in update_data.items():
        if value is not None and hasattr(existing, key):
            setattr(existing, key, value)
    
    session.add(existing)
    session.commit()
    session.refresh(existing)
    return True, existing

def delete_data(obj_name: str, obj_id: int, session: SessionDep):
    """
    Delete a record
    """
    model_class = obj_map.get(obj_name.lower())
    if not model_class:
        return False
    
    existing = session.exec(
        select(model_class).where(model_class.id == obj_id)
    ).first()
    
    if not existing:
        return False
    
    session.delete(existing)
    session.commit()
    return True

def get_single_data(obj_id: int, obj_name: str, session: SessionDep):
    """
    Get a single record by ID
    """
    model_class = obj_map.get(obj_name.lower())
    if not model_class:
        return None
    
    data = session.exec(
        select(model_class).where(model_class.id == obj_id)
    ).first()
    return data

# ---------- user-scoped (settings / billing / activity) ----------
def get_user_settings(session: Session, user_id: int):
    return session.exec(
        select(UserSettings).where(UserSettings.user_id == user_id)
    ).first()


def get_or_create_user_settings(session: Session, user_id: int):
    settings = get_user_settings(session, user_id)
    if settings:
        return settings
    _, settings = create_data("settings", {"user_id": user_id}, session)
    return settings


def get_user_billing(session: Session, user_id: int):
    return session.exec(
        select(UserBilling).where(UserBilling.user_id == user_id)
    ).first()


def get_or_create_user_billing(session: Session, user_id: int):
    billing = get_user_billing(session, user_id)
    if billing:
        return billing
    _, billing = create_data("billing", {"user_id": user_id}, session)
    return billing


def list_user_activities(session: Session, user_id: int, limit: int = 50, offset: int = 0):
    return session.exec(
        select(UserActivity)
        .where(UserActivity.user_id == user_id)
        .order_by(UserActivity.created_at.desc())
        .offset(offset)
        .limit(limit)
    ).all()


def log_activity(session: Session, user_id: int, action: str, status: str = "completed"):
    """Call this from other endpoints, e.g. log_activity(session, uid, "Generated Video")."""
    _, activity = create_data(
        "activity", {"user_id": user_id, "action": action, "status": status}, session
    )
    return activity