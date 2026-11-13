import json
import os
import re
from datetime import datetime

import fitz  # pymupdf
from sqlmodel import Session

import crud
from config import IMAGES_DIR, JSON_DIR
from database import engine
from utils.convert_tts import convert_to_speech
from utils.progress import no_progress
from utils.use_llm import convert_to_quiz, summarize_text

MIN_IMAGE_SIZE = 200  # skip tiny embedded images (logos, icons)
STAGE = "processing_pdf"


def make_name(title):
    """pdf title + current time, safe for filenames."""
    safe = re.sub(r"[^a-zA-Z0-9]+", "_", title).strip("_") or "untitled"
    return f"{safe}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"


def process_pdf(pdf_path, filename, user_id: int, progress=None):
    """Extract cover, title, text, images -> chunk -> summary/quiz/audio -> database.
    Returns a dict (title, cover, images, json_path, project_id).

    Order of events:
      1. read the pdf (cover + images saved in images/)
      2. json file created      (json/<name>.json, only "text" per chunk)
      3. project row created    (database, no chunks yet)
      4. every chunk gets summary, quiz, audio  (the json is re-saved after each chunk)
      5. chunk rows inserted    (database, all at once)
    """
    progress = progress or no_progress
    progress(STAGE, "reading_pdf", msg=filename, fraction=0.0)

    doc = fitz.open(pdf_path)
    try:
        if doc.page_count == 0:
            raise ValueError("This PDF has no pages.")

        title = (doc.metadata or {}).get("title") or os.path.splitext(filename)[0]
        name = make_name(title)

        # cover image = first page rendered as png
        cover_path = os.path.join(IMAGES_DIR, f"{name}_cover.png")
        doc[0].get_pixmap(dpi=100).save(cover_path)

        # text + embedded images
        text, image_paths = "", []
        for page_num, page in enumerate(doc, start=1):
            text += page.get_text() + "\n"
            for i, img in enumerate(page.get_images(full=True), start=1):
                data = doc.extract_image(img[0])
                if data["ext"] not in ("png", "jpg", "jpeg"):
                    continue
                if min(data["width"], data["height"]) < MIN_IMAGE_SIZE:
                    continue
                path = os.path.join(IMAGES_DIR, f"{name}_p{page_num}_{i}.{data['ext']}")
                with open(path, "wb") as f:
                    f.write(data["image"])
                image_paths.append(path)
    finally:
        doc.close()

    if not text.strip():
        raise ValueError("No text found in this PDF. Scanned PDFs need OCR first.")

    progress(STAGE, "pdf_read", msg=f"{len(text.split())} words, {len(image_paths)} images", fraction=0.03)

    json_path = convert_to_chunk(text, name)

    with Session(engine) as session:
        project = crud.create_project(session, title, json_path, user_id, cover_path)
        project_id = project.id

    progress(STAGE, "project_created", msg=f"project_id={project_id}, json={json_path}", fraction=0.05)

    try:
        loop_through_chunk(json_path, name, project_id, progress)
    except Exception:
        # don't leave a project with no content in the user's library.
        # The json and audio files stay on disk, so you can see how far it got.
        with Session(engine) as session:
            crud.delete_project(session, project_id, remove_files=False)
        raise

    return {
        "title": title,
        "cover": cover_path,
        "images": image_paths,
        "json_path": json_path,
        "project_id": project_id,
    }


def convert_to_chunk(text, name):
    """Split text into 500-word chunks and save to json."""
    words = text.split()
    chunks = {}
    for i in range(0, len(words), 500):
        chunks[f"chunk_{i // 500 + 1}"] = {"text": " ".join(words[i : i + 500])}

    json_path = os.path.join(JSON_DIR, f"{name}.json")
    save_json(json_path, chunks)
    return json_path


def save_json(json_path, data):
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def loop_through_chunk(json_path: str, name: str, project_id: int, progress=None) -> int:
    """Add summary/quiz/audio to every chunk, then insert the chunks into the database.
    The json is saved after every chunk. Returns the number of chunks inserted."""
    progress = progress or no_progress

    with open(json_path, encoding="utf-8") as f:
        chunks = json.load(f)
    total = len(chunks)

    def step(i, k, key, label):  # k = 0, 1, 2 (summary, quiz, audio)
        progress(STAGE, label, chunk=i, total=total, msg=key, fraction=0.05 + 0.9 * ((i - 1) * 3 + k) / (3 * total))

    for i, (key, chunk) in enumerate(chunks.items(), start=1):
        text = chunk["text"]

        step(i, 0, key, "summary")
        chunk["summarized_text"] = summarize_text(text)
        step(i, 1, key, "quiz")
        chunk["quiz"] = convert_to_quiz(text)
        step(i, 2, key, "audio")
        chunk["audio"] = convert_to_speech(text, f"{name}_{key}")

        chunk["project_name"] = name
        save_json(json_path, chunks)

    progress(STAGE, "saving_chunks_to_db", msg=f"{total} chunks", fraction=0.97)
    with Session(engine) as session:
        inserted = crud.insert_chunks(session=session, project_id=project_id, chunks=chunks)

    progress(STAGE, "stage_done", msg=f"{inserted} chunks saved", fraction=1.0)
    return inserted
