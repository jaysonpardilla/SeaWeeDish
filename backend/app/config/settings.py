import os
from pathlib import Path

# Base directory
BASE_DIR = Path(__file__).resolve().parent.parent.parent

# Model settings
# Must match training pipeline: EfficientNetV2B0 uses 224x224 input
TFLITE_MODEL_PATH = BASE_DIR / "model" / "seaweed_model7.tflite"
LABELS_PATH = BASE_DIR / "model" / "labels.json"
MODEL_INPUT_SIZE = 224

# Upload settings
UPLOAD_DIR = BASE_DIR / "uploads"
SAVED_IMAGES_DIR = BASE_DIR / "saved_images"
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB
ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "gif", "bmp"}

# API settings
API_TITLE = "PhycoSense Seaweed Identifier API"
API_VERSION = "1.0.0"
API_DESCRIPTION = "AI-powered seaweed species classification API"

# CORS settings
CORS_ORIGINS = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:8080",
    "http://192.168.1.*",  # Local network access
]

# Create uploads and saved images directories if they don't exist
UPLOAD_DIR.mkdir(exist_ok=True)
SAVED_IMAGES_DIR.mkdir(exist_ok=True)
