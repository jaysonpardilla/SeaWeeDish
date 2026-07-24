import logging
import time
import uuid
from fastapi import APIRouter, UploadFile, File, HTTPException
from pathlib import Path

from app.services import ModelService
from app.schemas import PredictionResponse, ErrorResponse
from app.utils import ImageProcessor
from app.config import UPLOAD_DIR, SAVED_IMAGES_DIR, MAX_FILE_SIZE, ALLOWED_EXTENSIONS

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["predictions"])


@router.post(
    "/predict",
    response_model=PredictionResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    summary="Predict seaweed species from image",
    description="Upload an image and get seaweed species prediction with confidence score"
)
async def predict(file: UploadFile = File(...)):
    """
    Predict seaweed species from uploaded image
    
    - **file**: Image file (JPEG, PNG, GIF, BMP)
    
    Returns prediction with confidence and all class probabilities
    """
    try:
        # Validate file type
        if not file.filename:
            raise HTTPException(status_code=400, detail="No filename provided")
        
        file_ext = Path(file.filename).suffix.lower().lstrip('.')
        if file_ext not in ALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid file type. Allowed types: {', '.join(ALLOWED_EXTENSIONS)}"
            )
        
        # Read file content
        file_content = await file.read()
        
        # Validate file size
        if len(file_content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"File size exceeds {MAX_FILE_SIZE / (1024*1024):.1f}MB limit"
            )
        
        # Save uploaded file temporarily for processing
        temp_filename = f"{uuid.uuid4()}_{file.filename}"
        temp_file_path = UPLOAD_DIR / temp_filename
        
        with open(temp_file_path, "wb") as f:
            f.write(file_content)
        
        try:
            # Load and preprocess image
            image = ImageProcessor.load_image_from_path(str(temp_file_path))
            
            # Get prediction from model
            model_service = ModelService()
            predicted_class, confidence, probabilities, processing_time = model_service.predict(image)
            
            # Save the processed image to saved_images directory
            saved_filename = f"{uuid.uuid4()}_{file.filename}"
            saved_file_path = SAVED_IMAGES_DIR / saved_filename
            saved_file_path.write_bytes(file_content)
            
            # Format response
            return PredictionResponse(
                prediction=predicted_class,
                confidence=round(confidence, 2),
                probabilities={k: round(v, 2) for k, v in probabilities.items()},
                processing_time=f"{processing_time:.2f}s",
                image_filename=saved_filename
            )
        
        finally:
            # Clean up temporary uploaded file
            try:
                temp_file_path.unlink()
            except:
                pass
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


@router.post(
    "/predict-base64",
    response_model=PredictionResponse,
    responses={400: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    summary="Predict from base64 encoded image",
    description="Send base64 encoded image data for prediction"
)
async def predict_base64(data: dict):
    """
    Predict seaweed species from base64 encoded image
    
    Request body:
    ```json
    {
        "image_data": "base64_encoded_image_string"
    }
    ```
    """
    try:
        if "image_data" not in data:
            raise HTTPException(status_code=400, detail="Missing 'image_data' field")
        
        import base64
        
        try:
            image_bytes = base64.b64decode(data["image_data"])
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid base64 encoding: {str(e)}")
        
        # Load image from bytes
        image = ImageProcessor.load_image_from_bytes(image_bytes)
        
        # Get prediction
        model_service = ModelService()
        predicted_class, confidence, probabilities, processing_time = model_service.predict(image)
        
        # Save the base64 image to saved_images directory
        saved_filename = f"{uuid.uuid4()}_image.png"
        saved_file_path = SAVED_IMAGES_DIR / saved_filename
        saved_file_path.write_bytes(image_bytes)
        
        return PredictionResponse(
            prediction=predicted_class,
            confidence=round(confidence, 2),
            probabilities={k: round(v, 2) for k, v in probabilities.items()},
            processing_time=f"{processing_time:.2f}s",
            image_filename=saved_filename
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Base64 prediction error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


@router.get(
    "/health",
    summary="Health check",
    description="Check if API and model are running"
)
async def health_check():
    """Check API and model health"""
    model_service = ModelService()
    return {
        "status": "healthy",
        "model_loaded": model_service.is_model_loaded(),
        "model_info": model_service.get_model_info()
    }
