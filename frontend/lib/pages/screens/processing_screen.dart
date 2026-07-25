// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image/image.dart' as img;
import '../../services/api_service.dart';
import 'result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String imagePath;

  const ProcessingScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late final AssetImage _backgroundImage;
  bool _isBackgroundPrecached = false;
  double _progress = 1;
  String _status = 'Initializing...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _backgroundImage = const AssetImage('lib/assets/images/background.png');
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _startProcessing();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isBackgroundPrecached) {
      precacheImage(_backgroundImage, context);
      _isBackgroundPrecached = true;
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  /// Smoothly animate progress from one value to another
  Future<void> _animateProgress(double from, double to, Duration duration) async {
    _progressController.reset();
    _progressController.duration = duration;

    late Animation<double> animation;
    animation = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    animation.addListener(() {
      setState(() {
        _progress = animation.value;
      });
    });

    await _progressController.forward();
  }

  void _startProcessing() async {
    try {
      // Convert image path to File
      final capturedImage = File(widget.imagePath);
      
      print('📊 Processing started for image: ${capturedImage.path}');
      print('📊 Image exists: ${await capturedImage.exists()}');
      print('📊 Image size: ${await capturedImage.length()} bytes');

      // Stage 1: Compress image (1-35%)
      print('📊 Starting image compression...');
      setState(() {
        _status = 'Compressing image...';
      });

      final stopwatch = Stopwatch()..start();
      final compressedFile = await _compressImage(capturedImage);
      stopwatch.stop();
      print('📊 Compression complete: ${compressedFile.path} (${stopwatch.elapsedMilliseconds}ms)');
      
      await _animateProgress(_progress, 35, const Duration(milliseconds: 800));

      // Stage 2: Upload to API (35-80%)
      setState(() {
        _status = 'Sending to server...';
      });

      print('📊 Calling API for prediction...');
      stopwatch.reset();
      stopwatch.start();
      final apiService = ApiService();
      final result = await apiService.predictFromImage(compressedFile);
      stopwatch.stop();
      
      print('📊 API Response - Prediction: ${result.prediction}, Confidence: ${result.confidence} (${stopwatch.elapsedMilliseconds}ms)');

      await _animateProgress(_progress, 80, const Duration(milliseconds: 1000));

      // Stage 3: Finalize (80-100%)
      setState(() {
        _status = 'Analyzing results...';
      });

      await _animateProgress(_progress, 100, const Duration(milliseconds: 600));
      
      setState(() {
        _status = 'Complete!';
      });

      // Small delay before navigation
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        print('📊 Navigating to ResultScreen with prediction: ${result.prediction}');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              capturedImage: capturedImage,
              prediction: result,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Processing error: $e');
      setState(() {
        _errorMessage = e.toString();
        _status = 'Analysis failed';
      });
      
      // Show error dialog with option to go back
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Error'),
                content: Text(_errorMessage ?? 'Unknown error occurred'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
        });
      }
    }
  }

  Future<File> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        return imageFile;
      }

      // Resize to max 800x800 for faster processing
      if (image.width > 800 || image.height > 800) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 800 : null,
          height: image.height > image.width ? 800 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // Compress to JPEG with quality 85
      final compressedBytes = img.encodeJpg(image, quality: 85);

      // Save to temp file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/phycosense_compressed.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      return tempFile;
    } catch (e) {
      return imageFile;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: _backgroundImage,
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Title
                  const Text(
                    'Analyzing Seaweed',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Circular progress indicator with image
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      // Progress circle with animated value
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: _progress / 100,
                          strokeWidth: 8,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.lerp(
                              const Color(0xFF0CA8B3),
                              const Color(0xFF06E3D0),
                              (_progress / 100).clamp(0.0, 1.0),
                            )!,
                          ),
                          backgroundColor: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      // Image in center
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0CA8B3).withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(90),
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Progress percentage text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_progress.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Processing',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  // Status text with animation
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _errorMessage != null ? Colors.red[300] : Colors.white,
                    ),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Identifying seaweed species...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  // Error message if any
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.5),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Analysis Failed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Go Back',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
