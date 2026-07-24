from pydantic import BaseModel
from typing import Dict


class PredictionResponse(BaseModel):
    """Response model for prediction results"""
    prediction: str
    confidence: float
    probabilities: Dict[str, float]
    processing_time: str
    image_filename: str
    model_version: str = "1.0"

    class Config:
        json_schema_extra = {
            "example": {
                "prediction": "lato",
                "confidence": 97.21,
                "probabilities": {
                    "lato": 97.21,
                    "padina": 1.2,
                    "seagrapes": 0.9
                },
                "processing_time": "0.42s",
                "image_filename": "12345678-abcd-efgh-ijkl-1234567890ab_image.png",
                "model_version": "1.0"
            }
        }


class ErrorResponse(BaseModel):
    """Response model for errors"""
    error: str
    detail: str = None

    class Config:
        schema_extra = {
            "example": {
                "error": "Invalid file type",
                "detail": "Only JPEG, PNG, GIF, and BMP files are allowed"
            }
        }
