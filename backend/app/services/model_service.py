import numpy as np
import time
import logging
import cv2
import json
from pathlib import Path
from typing import Tuple, Dict

try:
    import tensorflow as tf
except ImportError:
    tf = None

from app.config import TFLITE_MODEL_PATH, LABELS_PATH, MODEL_INPUT_SIZE
from app.utils import ImageProcessor

logger = logging.getLogger(__name__)


class ModelService:
    """Service for model loading and inference"""
    
    _instance = None
    _interpreter = None
    _class_names = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(ModelService, cls).__new__(cls)
        return cls._instance
    
    def __init__(self):
        if self._interpreter is None:
            self._load_model()
    
    def _load_model(self):
        """Load the TFLite model and class labels on initialization"""
        try:
            # Load TFLite model
            if TFLITE_MODEL_PATH.exists():
                logger.info(f"Loading TFLite model from {TFLITE_MODEL_PATH}")
                self._interpreter = tf.lite.Interpreter(model_path=str(TFLITE_MODEL_PATH))
                self._interpreter.allocate_tensors()
                logger.info("TFLite model loaded successfully")
            else:
                logger.warning(f"Model not found at {TFLITE_MODEL_PATH}")
                logger.info("Model will be loaded when available")
            
            # Load class labels from JSON
            if LABELS_PATH.exists():
                logger.info(f"Loading class labels from {LABELS_PATH}")
                with open(LABELS_PATH, 'r') as f:
                    self._class_names = json.load(f)
                logger.info(f"Loaded {len(self._class_names)} class labels: {self._class_names}")
            else:
                logger.warning(f"Labels file not found at {LABELS_PATH}")
        except Exception as e:
            logger.error(f"Error loading model/labels: {str(e)}")
            raise RuntimeError(f"Failed to load model/labels: {str(e)}")
    

    
    def _preprocess_image_with_size(self, image: np.ndarray, input_size: int) -> np.ndarray:
        """
        Preprocess image for TFLite model inference with specified input size.
        EXACT MATCH for training pipeline:
        - Convert BGR to RGB
        - Resize to specified input size
        - Use TensorFlow's preprocess_input (same as training)
        """
        from tensorflow.keras.applications.efficientnet_v2 import preprocess_input
        
        # Convert BGR to RGB
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # Resize to specified input size
        image_resized = cv2.resize(
            image_rgb,
            (input_size, input_size),
            interpolation=cv2.INTER_LINEAR
        )
        
        # Convert to float32
        image_float = image_resized.astype(np.float32)
        
        # CRITICAL: Use exact same preprocessing as training!
        # tf.keras.applications.efficientnet_v2.preprocess_input
        # normalizes images to [-1, 1] range
        image_preprocessed = preprocess_input(image_float)
        
        # Add batch dimension
        image_batch = np.expand_dims(image_preprocessed, axis=0)
        
        return image_batch
    

    def predict_tflite(self, image: np.ndarray) -> Tuple[str, float, Dict[str, float], float]:
        """
        Perform prediction using TFLite model
        
        Returns:
            Tuple of (predicted_class, confidence, probabilities_dict, processing_time)
        """
        if self._interpreter is None:
            raise RuntimeError("TFLite model not loaded")
        
        if self._class_names is None:
            raise RuntimeError("Class labels not loaded")
        
        start_time = time.time()
        
        try:
            # Get input and output tensor details
            input_details = self._interpreter.get_input_details()
            output_details = self._interpreter.get_output_details()
            
            # Get expected input size from model (shape is [batch, height, width, channels])
            expected_size = input_details[0]['shape'][1]  # height (assumes square input)
            
            # DEBUG: Log input image info
            logger.debug(f"[DEBUG] Input image shape: {image.shape}, dtype: {image.dtype}, range: [{image.min():.2f}, {image.max():.2f}]")
            
            # Preprocess image with detected input size
            processed_image = self._preprocess_image_with_size(image, expected_size)
            
            # DEBUG: Log preprocessed image info
            logger.debug(f"[DEBUG] Preprocessed image shape: {processed_image.shape}, dtype: {processed_image.dtype}")
            logger.debug(f"[DEBUG] Preprocessed image range: [{processed_image.min():.4f}, {processed_image.max():.4f}]")
            logger.debug(f"[DEBUG] Expected model input: {expected_size}x{expected_size}")
            
            # Set input tensor
            self._interpreter.set_tensor(
                input_details[0]['index'],
                processed_image.astype(np.float32)
            )
            
            # Run inference
            self._interpreter.invoke()
            
            # Get output tensor
            output_data = self._interpreter.get_tensor(output_details[0]['index'])
            predictions = output_data[0]
            
            # DEBUG: Log raw model output
            logger.debug(f"[DEBUG] Raw model output: {predictions}")
            logger.debug(f"[DEBUG] Output range: [{predictions.min():.4f}, {predictions.max():.4f}]")
            logger.debug(f"[DEBUG] Output sum (should be ~1.0 for softmax): {predictions.sum():.4f}")
            
            # Get results
            predicted_idx = np.argmax(predictions)
            confidence = float(np.max(predictions) * 100)
            
            # DEBUG: Log prediction
            logger.debug(f"[DEBUG] Argmax index: {predicted_idx}, Confidence: {confidence:.2f}%")
            logger.debug(f"[DEBUG] Predicted class: {self._class_names[predicted_idx]}")
            
            # Create probabilities dictionary
            probabilities = {
                class_name: float(prob * 100)
                for class_name, prob in zip(self._class_names, predictions)
            }
            
            processing_time = time.time() - start_time
            
            logger.info(f"Prediction: {self._class_names[predicted_idx]} ({confidence:.2f}%) | Processing time: {processing_time:.3f}s")
            
            return self._class_names[predicted_idx], confidence, probabilities, processing_time
        
        except Exception as e:
            logger.error(f"Error during TFLite prediction: {str(e)}")
            raise RuntimeError(f"Prediction failed: {str(e)}")
    
    def predict(self, image: np.ndarray) -> Tuple[str, float, Dict[str, float], float]:
        """
        Perform prediction using TFLite model
        
        Returns:
            Tuple of (predicted_class, confidence, probabilities_dict, processing_time)
        """
        return self.predict_tflite(image)
    
    def is_model_loaded(self) -> bool:
        """Check if model is loaded"""
        return self._interpreter is not None and self._class_names is not None
    
    def get_model_info(self) -> Dict:
        """Get model information"""
        return {
            "classes": self._class_names if self._class_names is not None else [],
            "num_classes": len(self._class_names) if self._class_names is not None else 0,
            "input_size": MODEL_INPUT_SIZE,
            "model_type": "tflite",
            "is_loaded": self.is_model_loaded()
        }
