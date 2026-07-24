import cv2
import numpy as np
from io import BytesIO
from PIL import Image
from pathlib import Path
from app.config import MODEL_INPUT_SIZE


class ImageProcessor:
    """Utility class for image processing"""
    
    @staticmethod
    def load_image_from_path(image_path: str) -> np.ndarray:
        """Load image from file path"""
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Failed to load image from {image_path}")
        return image
    
    @staticmethod
    def load_image_from_bytes(image_bytes: bytes) -> np.ndarray:
        """Load image from bytes"""
        try:
            nparr = np.frombuffer(image_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if image is None:
                raise ValueError("Failed to decode image bytes")
            return image
        except Exception as e:
            raise ValueError(f"Error loading image from bytes: {str(e)}")
    
    @staticmethod
    def preprocess_image(image: np.ndarray) -> np.ndarray:
        """
        Preprocess image for model inference (deprecated - use preprocess_image_efficientnet)
        Kept for backwards compatibility but should not be used for seaweed prediction.
        
        Note: This normalizes to [0, 1] which does NOT match training pipeline.
        Use preprocess_image_efficientnet instead for correct results.
        """
        # Convert BGR to RGB
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # Resize to model input size
        image_resized = cv2.resize(
            image_rgb,
            (MODEL_INPUT_SIZE, MODEL_INPUT_SIZE),
            interpolation=cv2.INTER_LINEAR
        )
        
        # Normalize to [0, 1] range
        image_normalized = image_resized.astype(np.float32) / 255.0
        
        # Add batch dimension
        image_batch = np.expand_dims(image_normalized, axis=0)
        
        return image_batch
    
    @staticmethod
    def preprocess_image_efficientnet(image: np.ndarray) -> np.ndarray:
        """
        Preprocess image for EfficientNetV2B0 model
        EXACT MATCH for training pipeline:
        - Convert BGR to RGB
        - Resize to 224x224 (model input size)
        - Use TensorFlow's preprocess_input (same as training)
        - Add batch dimension
        
        NO data augmentation during inference (only during training)
        """
        from tensorflow.keras.applications.efficientnet_v2 import preprocess_input
        
        # Convert BGR to RGB
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # Resize to model input size (224x224 for EfficientNetV2B0)
        image_resized = cv2.resize(
            image_rgb,
            (MODEL_INPUT_SIZE, MODEL_INPUT_SIZE),
            interpolation=cv2.INTER_LINEAR
        )
        
        # Convert to float32
        image_float = image_resized.astype(np.float32)
        
        # CRITICAL: Use exact same preprocessing as training!
        # This normalizes to [-1, 1] range
        image_preprocessed = preprocess_input(image_float)
        
        # Add batch dimension [1, 224, 224, 3]
        image_batch = np.expand_dims(image_preprocessed, axis=0)
        
        return image_batch
    
    @staticmethod
    def compress_image(image_path: str, quality: int = 85) -> str:
        """Compress image and save it"""
        try:
            img = Image.open(image_path)
            
            # Convert RGBA to RGB if necessary
            if img.mode in ('RGBA', 'LA', 'P'):
                rgb_img = Image.new('RGB', img.size, (255, 255, 255))
                rgb_img.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                img = rgb_img
            
            # Save with compression
            img.save(image_path, 'JPEG', quality=quality, optimize=True)
            return image_path
        except Exception as e:
            raise ValueError(f"Error compressing image: {str(e)}")
    
    @staticmethod
    def validate_image(file_path: str, max_size: int) -> bool:
        """Validate image file"""
        try:
            # Check file exists
            if not Path(file_path).exists():
                raise FileNotFoundError("File not found")
            
            # Check file size
            file_size = Path(file_path).stat().st_size
            if file_size > max_size:
                raise ValueError(f"File size exceeds {max_size} bytes")
            
            # Try to open as image
            img = Image.open(file_path)
            img.verify()
            
            return True
        except Exception as e:
            raise ValueError(f"Invalid image: {str(e)}")
