import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// API Service for PhycoSense Backend
/// Handles all communication with the FastAPI backend
class ApiService {
  // Singleton instance
  static final ApiService _instance = ApiService._internal();
  
  // Backend configuration
  // Using machine's actual IP address on the network
  static const String _baseUrl = 'http://10.0.0.77:8000/api';
  
  static const int _timeout = 30; // seconds

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  /// Get the backend URL
  /// Override this method or use environment variables for different environments
  String get backendUrl => _baseUrl;

  /// Health check - Verify backend is running
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http
          .get(
            Uri.parse('$backendUrl/health'),
          )
          .timeout(Duration(seconds: _timeout));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Health check error: $e');
      rethrow;
    }
  }

  /// Predict seaweed species from image file
  /// 
  /// [imageFile] - File object of the image
  /// Returns [PredictionResult] with prediction details
  Future<PredictionResult> predictFromImage(File imageFile) async {
    try {
      print('🔗 API: Sending image to /predict endpoint');
      print('🔗 API: Image path: ${imageFile.path}');
      print('🔗 API: Image exists: ${await imageFile.exists()}');
      print('🔗 API: Image size: ${await imageFile.length()} bytes');
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/predict'),
      );

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      print('� API: Request built, sending...');
      
      // Send request with timeout
      final streamResponse = await request.send().timeout(
            Duration(seconds: _timeout),
          );

      final response = await http.Response.fromStream(streamResponse);

      print('🔗 API: Response status: ${response.statusCode}');
      print('🔗 API: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        print('🔗 API: Parsed JSON: $jsonData');
        final result = PredictionResult.fromJson(jsonData);
        print('🔗 API: Prediction result - ${result.prediction} (${result.confidence}%)');
        return result;
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          message: error['detail'] ?? 'Prediction failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('❌ API: Prediction error: $e');
      debugPrint('Prediction error: $e');
      rethrow;
    }
  }

  /// Predict from base64 encoded image data
  /// 
  /// [imageBytes] - Image data as bytes
  /// [imageName] - Optional image name for logging
  /// Returns [PredictionResult] with prediction details
  Future<PredictionResult> predictFromBase64(
    List<int> imageBytes, {
    String? imageName,
  }) async {
    try {
      final base64String = base64Encode(imageBytes);

      final response = await http
          .post(
            Uri.parse('$backendUrl/predict-base64'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'image_data': base64String,
            }),
          )
          .timeout(Duration(seconds: _timeout));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return PredictionResult.fromJson(jsonData);
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          message: error['detail'] ?? 'Prediction failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Base64 prediction error: $e');
      rethrow;
    }
  }

  /// Validate image before sending to backend
  /// 
  /// [imageFile] - File to validate
  /// Returns true if valid, throws exception otherwise
  static bool validateImageFile(File imageFile) {
    const maxSizeMB = 5;
    const maxSizeBytes = maxSizeMB * 1024 * 1024;
    
    final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp'];
    final fileExtension = imageFile.path.split('.').last.toLowerCase();

    // Check file extension
    if (!allowedExtensions.contains(fileExtension)) {
      throw ApiException(
        message: 'Invalid file type. Allowed: ${allowedExtensions.join(', ')}',
        statusCode: 400,
      );
    }

    // Check file size
    final fileSizeBytes = imageFile.lengthSync();
    if (fileSizeBytes > maxSizeBytes) {
      throw ApiException(
        message: 'File size exceeds ${maxSizeMB}MB limit',
        statusCode: 400,
      );
    }

    return true;
  }

  /// Check backend connectivity
  Future<bool> isBackendAvailable() async {
    try {
      await healthCheck();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Prediction result model
class PredictionResult {
  final String prediction;
  final double confidence;
  final Map<String, double> probabilities;
  final String processingTime;
  final String modelVersion;

  PredictionResult({
    required this.prediction,
    required this.confidence,
    required this.probabilities,
    required this.processingTime,
    this.modelVersion = '1.0',
  });

  /// Create PredictionResult from JSON
  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final probs = <String, double>{};
    
    if (json['probabilities'] is Map) {
      (json['probabilities'] as Map).forEach((key, value) {
        probs[key as String] = (value as num).toDouble();
      });
    }

    return PredictionResult(
      prediction: json['prediction'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      probabilities: probs,
      processingTime: json['processing_time'] as String? ?? '0s',
      modelVersion: json['model_version'] as String? ?? '1.0',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'prediction': prediction,
    'confidence': confidence,
    'probabilities': probabilities,
    'processing_time': processingTime,
    'model_version': modelVersion,
  };

  @override
  String toString() =>
      'PredictionResult(prediction: $prediction, confidence: ${confidence.toStringAsFixed(2)}%)';
}

/// Custom API exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ApiException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}
