import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

from app.config import API_TITLE, API_VERSION, API_DESCRIPTION, CORS_ORIGINS
from app.routes import router as prediction_router
from app.services import ModelService

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title=API_TITLE,
    version=API_VERSION,
    description=API_DESCRIPTION,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(prediction_router)


@app.on_event("startup")
async def startup_event():
    """Initialize model on startup"""
    logger.info("Starting PhycoSense API...")
    try:
        model_service = ModelService()
        if model_service.is_model_loaded():
            logger.info("✓ Model loaded successfully")
        else:
            logger.warning("⚠ Model not found - will be loaded when available")                                                                   
    except Exception as e:
        logger.error(f"✗ Error during startup: {str(e)}")


@app.on_event("shutdown")                                                                                                                                 
async def shutdown_event():
    """Cleanup on shutdown"""                                                                                                                             
    logger.info("Shutting down PhycoSense API...")


@app.get("/", tags=["root"])
async def read_root():
    """API Root - Returns API information"""
    return {
        "name": API_TITLE,
        "version": API_VERSION,
        "description": API_DESCRIPTION,
        "docs": "/api/docs",
        "endpoints": {
            "predict": "/api/predict (POST)",
            "predict_base64": "/api/predict-base64 (POST)",
            "health": "/api/health (GET)"
        }
    }


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "detail": str(exc)}
    )


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
