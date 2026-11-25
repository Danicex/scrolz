from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from api import project, user, library
from database import create_db_and_tables


@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()  # runs once when the app starts
    yield

app = FastAPI(lifespan=lifespan)

@app.get("/")
def read_root():
    return {"Hello": "scrolz"}

app.mount("/uploads", StaticFiles(directory="process_pdf"), name="pdf uploads")
app.mount("/audio", StaticFiles(directory="audio"), name="audio")
app.mount("/videos", StaticFiles(directory="videos"), name="output videos")

app.include_router(user.router)
app.include_router(project.router)
app.include_router(library.router)

# run: uvicorn main:app --reload
