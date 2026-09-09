// ignore_for_file: deprecated_member_use, unused_local_variable, avoid_print

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'processing_screen.dart';

class ScanScreen extends StatefulWidget {
  final ValueChanged<int>? onTabChanged;

  const ScanScreen({super.key, this.onTabChanged});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  CameraController? _cameraController;
  late Future<void> _initializeCameraFuture;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isCapturing = false; // Prevent multiple simultaneous captures
  int _cameraIndex = 0;
  XFile? _selectedImage;
  final GlobalKey _cameraPreviewKey = GlobalKey();
  static const double _cropBoxWidth = 250;
  static const double _cropBoxHeight = 280;

  static const List<String> _modes = [
    'Scan',
    'Upload',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraFuture = _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('📷 App resumed, checking camera...');
      // When app is resumed, check if camera needs to be reinitialized
      if (_cameraController == null || !_isCameraInitialized) {
        print('📷 Reinitializing camera...');
        _initializeCameraFuture = _initializeCamera();
        setState(() {});
      }
    } else if (state == AppLifecycleState.paused) {
      print('📷 App paused');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Dispose old controller if it exists
      if (_cameraController != null) {
        try {
          await _cameraController!.dispose();
        } catch (e) {
          print('📷 Error disposing old camera controller: $e');
        }
        _cameraController = null;
      }

      // Reset initialization flag
      setState(() => _isCameraInitialized = false);

      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      
      if (!cameraStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required to take pictures')),
          );
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      // Ensure flash/torch is off by default until user explicitly enables it
      try {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
      } catch (e) {
        // Not all devices support flash control; ignore errors
        print('📷 Warning: could not set flash mode: $e');
      }
      print('📷 Camera initialized successfully');
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;

      _cameraIndex = (_cameraIndex + 1) % cameras.length;
      if (_cameraController != null) {
        await _cameraController!.dispose();
      }

      _cameraController = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      print('Error switching camera: $e');
    }
  }

  Future<File> _cropImageToPreviewBox(String imagePath) async {
    try {
      final previewSize = _getPreviewSize();
      if (previewSize == null) {
        print('⚠️ Preview size unavailable, sending full image.');
        return File(imagePath);
      }

      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        print('⚠️ Unable to decode captured image, sending full image.');
        return imageFile;
      }

      final previewWidth = previewSize.width;
      final previewHeight = previewSize.height;
      final left = ((previewWidth - _cropBoxWidth) / 2).clamp(0.0, previewWidth - 1.0);
      final top = ((previewHeight - _cropBoxHeight) / 2).clamp(0.0, previewHeight - 1.0);
      final cropWidth = _cropBoxWidth.clamp(1.0, previewWidth - left);
      final cropHeight = _cropBoxHeight.clamp(1.0, previewHeight - top);

      final scaleX = originalImage.width / previewWidth;
      final scaleY = originalImage.height / previewHeight;
      final cropX = (left * scaleX).round().clamp(0, originalImage.width - 1);
      final cropY = (top * scaleY).round().clamp(0, originalImage.height - 1);
      final cropW = (cropWidth * scaleX).round().clamp(1, originalImage.width - cropX);
      final cropH = (cropHeight * scaleY).round().clamp(1, originalImage.height - cropY);

      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final tempDir = Directory.systemTemp;
      final croppedFile = File(
        '${tempDir.path}/seaweed_capture_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 90));
      return croppedFile;
    } catch (e) {
      print('❌ Error cropping captured image: $e');
      return File(imagePath);
    }
  }

  Size? _getPreviewSize() {
    final context = _cameraPreviewKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.size;
    }
    return null;
  }

  Future<void> _toggleFlash() async {
    try {
      if (_isFlashOn) {
        if (_cameraController == null) return;
        await _cameraController!.setFlashMode(FlashMode.off);
        setState(() => _isFlashOn = false);
      } else {
        if (_cameraController == null) return;
        await _cameraController!.setFlashMode(FlashMode.torch);
        setState(() => _isFlashOn = true);
      }
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_cameraController != null) {
      _cameraController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FBFC),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _selectedIndex == 0 ? _buildScanCard() : _buildUploadCard(),
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // Back button to request AppShell switch back to Home
                  GestureDetector(
                    onTap: () {
                      // If parent provided a tab change callback, use it to avoid popping the app route
                      if (widget.onTabChanged != null) {
                        widget.onTabChanged!(0);
                        return;
                      }
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Mode tabs expanded to fill remaining space
                  Expanded(child: _buildModeTabs()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: List.generate(_modes.length, (index) {
          final bool selected = _selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(left: index == 0 ? 0 : 10),
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0B5C7A) : Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? const Color(0xFF0B5C7A) : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(
                    _modes[index],
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF22324A),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  
  Widget _buildScanCard() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.fromARGB(255, 113, 124, 129), Color(0xFF0C7A9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
      child: FutureBuilder<void>(
        future: _initializeCameraFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _isCameraInitialized) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Camera Preview full width with preserved aspect ratio
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(5),
                  ),
                  child: AspectRatio(
                    key: _cameraPreviewKey,
                    aspectRatio: _cameraController!.value.aspectRatio,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
                // Scanning frame overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CustomPaint(
                      painter: ScannerOverlayPainter(),
                    ),
                  ),
                ),
                // Camera status indicator removed
                // Control Buttons overlayed above the navigation area
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 70,
                  child: AbsorbPointer(
                    absorbing: _isCapturing,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildOverlayButton(
                            icon: Icons.flip_camera_android_rounded,
                            onTap: _isCapturing ? () {} : _switchCamera,
                          ),
                          const SizedBox(width: 16),
                          _buildOverlayButton(
                            icon: Icons.circle_rounded,
                            isPrimary: true,
                            onTap: _isCapturing
                                ? () {}
                                : () async {
                                    if (_isCapturing) {
                                      print('⚠️ Capture already in progress...');
                                      return;
                                    }

                                    if (_isCameraInitialized && _cameraController != null) {
                                      if (_isCapturing) {
                                        print('⚠️ Capture already in progress...');
                                        return;
                                      }

                                      _isCapturing = true;
                                      if (mounted) {
                                        setState(() {});
                                      }

                                      try {
                                        print('📷 Starting to take picture...');

                                        final image = await _cameraController!.takePicture();
                                        print('📷 Picture taken: ${image.path}');

                                        final croppedFile = await _cropImageToPreviewBox(image.path);
                                        print('✂️ Cropped image path: ${croppedFile.path}');

                                        if (mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ProcessingScreen(
                                                imagePath: croppedFile.path,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        print('❌ Error taking picture: $e');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      } finally {
                                        _isCapturing = false;
                                        if (mounted) {
                                          setState(() {});
                                        }
                                      }
                                    } else {
                                      print('❌ Camera not initialized. Initialized: $_isCameraInitialized, Controller: ${_cameraController != null}');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Camera is not ready. Please wait...'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                          const SizedBox(width: 16),
                          _buildOverlayButton(
                            icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            active: _isFlashOn,
                            onTap: _isCapturing ? () {} : _toggleFlash,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Container(
              color: const Color(0xFF1A4D5C),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool isPrimary = false,
    bool active = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPrimary
            ? const Color(0xFF0CA8B3)
            : active
                ? const Color(0xFF0CA8B3)
                : Colors.white.withOpacity(0.2),
        border: Border.all(
          color: isPrimary || active
              ? const Color(0xFF0CA8B3)
              : Colors.white.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: Colors.white24,
          child: Padding(
            padding: EdgeInsets.all(isPrimary ? 8 : 6),
            child: Icon(
              icon,
              color: Colors.white,
              size: isPrimary ? 26 : 18,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      // Request storage permission
      final photosStatus = await Permission.photos.request();
      final storageStatus = await Permission.storage.request();
      
      if (!photosStatus.isGranted && !storageStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required to pick images')),
          );
        }
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Widget _buildUploadCard() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FBFC), Color(0xFFF0F6F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Image preview or upload area (with embedded "Pick another")
                    Container(
                      width: double.infinity,
                      height: 170,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF0B5C7A),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(_selectedImage!.path),
                                    fit: BoxFit.cover,
                                  ),
                                  // Pick another button inside image container
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await _pickImage();
                                      },
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                        size: 14,
                                        color: Color(0xFF0B5C7A),
                                      ),
                                      label: const Text(
                                        'Pick another',
                                        style: TextStyle(
                                          color: Color(0xFF0B5C7A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF0B5C7A)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        backgroundColor: Colors.white.withOpacity(0.85),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: _pickImage,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF0B5C7A).withOpacity(0.08),
                                    ),
                                    child: const Icon(
                                      Icons.cloud_upload_rounded,
                                      color: Color(0xFF0B5C7A),
                                      size: 48,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Upload a seaweed image',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF083C7E),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tap to select from gallery',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7A8D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Description
                    const Text(
                      'Choose a clear, well-lit photo of the seaweed for best results. The image will be analyzed to identify the species and provide detailed information.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7A8D),
                        height: 1.4,
                      ),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 200,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Prevent multiple simultaneous uploads
                            if (_isCapturing) {
                              print('⚠️ Upload already in progress...');
                              return;
                            }

                            try {
                              setState(() => _isCapturing = true);
                              final imageFile = File(_selectedImage!.path);

                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProcessingScreen(
                                      imagePath: imageFile.path,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              print('❌ Error uploading image: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              setState(() => _isCapturing = false);
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 20),
                          label: const Text('Analyze'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: const Color.fromARGB(228, 83, 154, 179),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Action buttons removed - Analyze button now in center
        ],
      ),
    );
  }

}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw corner indicators
    final cornerSize = 20.0;
    
    // Top-left
    canvas.drawLine(const Offset(0, 0), Offset(cornerSize, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerSize), paint);
    
    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerSize, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerSize), paint);
    
    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(cornerSize, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerSize), paint);
    
    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerSize, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerSize), paint);
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) => false;
}
