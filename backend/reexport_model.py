"""
Re-export Trained Model to TFLite
This script properly converts the trained Keras model to TFLite format
Make sure to run this in the same directory as your trained model (best_seaweed_model.keras)
"""

import os
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import tensorflow as tf
import json
from pathlib import Path

print("=" * 80)
print("🔄 MODEL RE-EXPORT TO TFLITE")
print("=" * 80)

# Check if trained model exists
TRAINED_MODEL_PATH = Path("model/best_seaweed_model.keras")
OUTPUT_TFLITE_PATH = Path("model/3class_model.tflite")

if not TRAINED_MODEL_PATH.exists():
    print(f"\n❌ ERROR: Trained model not found at {TRAINED_MODEL_PATH}")
    print(f"   Make sure you're running this script in the backend directory")
    exit(1)

print(f"\n✓ Found trained model: {TRAINED_MODEL_PATH}")
print(f"  File size: {TRAINED_MODEL_PATH.stat().st_size / 1024 / 1024:.2f} MB")

# Load the trained Keras model
print(f"\n⏳ Loading Keras model...")
try:
    model = tf.keras.models.load_model(str(TRAINED_MODEL_PATH))
    print(f"✓ Model loaded successfully")
    print(f"  Input shape: {model.input_shape}")
    print(f"  Output shape: {model.output_shape}")
except Exception as e:
    print(f"❌ ERROR loading model: {e}")
    exit(1)

# Get class names from labels.json
LABELS_PATH = Path("model/labels.json")
if LABELS_PATH.exists():
    with open(LABELS_PATH) as f:
        class_names = json.load(f)
    print(f"\n✓ Class labels found: {class_names}")
else:
    print(f"\n⚠️  labels.json not found at {LABELS_PATH}")
    class_names = None

# Convert to TFLite
print(f"\n⏳ Converting to TFLite format...")
print(f"  Applying: tf.lite.Optimize.DEFAULT")

try:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Optional: Set target spec for better optimization
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]
    
    tflite_model = converter.convert()
    
    print(f"✓ Conversion successful")
    print(f"  TFLite model size: {len(tflite_model) / 1024 / 1024:.2f} MB")
    
except Exception as e:
    print(f"❌ ERROR during conversion: {e}")
    exit(1)

# Save TFLite model
print(f"\n⏳ Saving TFLite model to {OUTPUT_TFLITE_PATH}...")

OUTPUT_TFLITE_PATH.parent.mkdir(parents=True, exist_ok=True)

try:
    with open(OUTPUT_TFLITE_PATH, "wb") as f:
        bytes_written = f.write(tflite_model)
    
    print(f"✓ TFLite model saved")
    print(f"  File size: {OUTPUT_TFLITE_PATH.stat().st_size / 1024 / 1024:.2f} MB")
    print(f"  Bytes written: {bytes_written / 1024 / 1024:.2f} MB")
    
except Exception as e:
    print(f"❌ ERROR saving TFLite model: {e}")
    exit(1)

# Verify the saved model
print(f"\n⏳ Verifying TFLite model...")

try:
    interpreter = tf.lite.Interpreter(model_path=str(OUTPUT_TFLITE_PATH))
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print(f"✓ TFLite model verified")
    print(f"\n  INPUT TENSOR:")
    print(f"    Index: {input_details[0]['index']}")
    print(f"    Shape: {input_details[0]['shape']}")
    print(f"    Dtype: {input_details[0]['dtype']}")
    
    print(f"\n  OUTPUT TENSOR:")
    print(f"    Index: {output_details[0]['index']}")
    print(f"    Shape: {output_details[0]['shape']}")
    print(f"    Dtype: {output_details[0]['dtype']}")
    
except Exception as e:
    print(f"❌ ERROR verifying TFLite model: {e}")
    exit(1)

# Test inference with random input
print(f"\n⏳ Testing inference with random input...")

try:
    import numpy as np
    
    test_input = np.random.uniform(-1, 1, (1, 224, 224, 3)).astype(np.float32)
    
    interpreter.set_tensor(input_details[0]['index'], test_input)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])[0]
    
    pred_idx = np.argmax(output)
    confidence = np.max(output) * 100
    
    print(f"✓ Inference test successful")
    print(f"\n  Test output: {output}")
    print(f"  Predicted index: {pred_idx}")
    print(f"  Confidence: {confidence:.2f}%")
    
    if class_names:
        print(f"  Predicted class: {class_names[pred_idx]}")
    
except Exception as e:
    print(f"❌ ERROR during inference test: {e}")
    exit(1)

# Verify labels.json exists and is up-to-date
print(f"\n⏳ Verifying labels.json...")

if LABELS_PATH.exists():
    with open(LABELS_PATH) as f:
        existing_labels = json.load(f)
    
    print(f"✓ labels.json already exists: {existing_labels}")
else:
    print(f"❌ labels.json not found. The backend expects labels.json in the model directory.")
    print(f"   Make sure to save it from your training script.")

print("\n" + "=" * 80)
print("✅ MODEL RE-EXPORT COMPLETE!")
print("=" * 80)
print(f"""
Summary:
  ✓ Keras model loaded: {TRAINED_MODEL_PATH}
  ✓ TFLite model saved: {OUTPUT_TFLITE_PATH}
  ✓ Labels verified: {class_names}

Next steps:
  1. Run the backend server: python run_server.py
  2. Test with sample images to verify predictions are correct
  3. If predictions are still always the same class, check:
     - Backend logs for [DEBUG] messages showing model output
     - Run: python debug_model_comprehensive.py
""")
