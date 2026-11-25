#!/bin/bash

set -e

# Activate virtual environment
source myenv/bin/activate

# Start FastAPI in the background
uvicorn main:app --reload &
FASTAPI_PID=$!

# Start Celery worker in the background (GPU hidden so PyTorch uses CPU)
CUDA_VISIBLE_DEVICES="" celery -A celery_app worker --loglevel=info &
CELERY_PID=$!

# # Stop both processes when the script exits
# trap 'kill $FASTAPI_PID $CELERY_PID 2>/dev/null' EXIT INT TERM
# pkill -f "celery -A celery_app" && pkill -f "uvicorn main:app"

# # Wait for both processes
# wait flutter run --dart-define-from-file=env.json
