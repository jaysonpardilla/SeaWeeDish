// ignore_for_file: unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../../services/api_service.dart';
import 'recommended_recipes_screen.dart';

class ResultScreen extends StatefulWidget {
  final dynamic capturedImage;
  final PredictionResult? prediction;

  const ResultScreen({
    super.key,
    required this.capturedImage,
    this.prediction,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static const int _minimumConfidenceToSave = 70;

  late String seaweedName;
  late int confidence;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  LatLng? _userLocation;
  bool _isSavingToMap = true;
  String? _mapSaveStatus;

  @override
  void initState() {
    super.initState();

    print('📋 ResultScreen initState');
    print('📋 Captured image type: ${widget.capturedImage.runtimeType}');
    print('📋 Prediction: ${widget.prediction}');

    if (widget.prediction != null) {
      seaweedName = widget.prediction!.prediction;
      confidence = widget.prediction!.confidence.toInt();
      if (confidence <= _minimumConfidenceToSave) {
        seaweedName = 'Unrecognized';
      }
      print('📋 Using prediction - Name: $seaweedName, Confidence: $confidence');
    } else {
      print('📋 Using fallback mock data');
    }

    Future.microtask(() => _saveResultToDeviceHistory());

    if (confidence > _minimumConfidenceToSave) {
      _saveResultToMap();
    } else {
      if (mounted) {
        setState(() {
          _isSavingToMap = false;
          _mapSaveStatus = 'Confidence is 70% or below. Result was not saved to the map.';
        });
      }
    }
  }

  Future<void> _saveResultToMap() async {
    if (!mounted) return;

    if (confidence <= _minimumConfidenceToSave) {
      if (mounted) {
        setState(() {
          _isSavingToMap = false;
          _mapSaveStatus = 'Confidence is 70% or below. Result was not saved to the map.';
        });
      }
      return;
    }

    try {
      print('🗺️ Starting map save process...');
      print('🗺️ Current user ID: guest_user');
      print('🗺️ Seaweed name: $seaweedName, Confidence: $confidence');

      final permission = await Geolocator.checkPermission();
      print('🗺️ Location permission: $permission');
      
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('🗺️ Requesting location permission...');
        final requested = await Geolocator.requestPermission();
        print('🗺️ Permission request result: $requested');
        
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() {
              _isSavingToMap = false;
              _mapSaveStatus = 'Location permission was not granted.';
            });
          }
          return;
        }
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('🗺️ Location service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isSavingToMap = false;
            _mapSaveStatus = 'Location services are disabled.';
          });
        }
        return;
      }

      print('🗺️ Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      print('🗺️ Got position: ${position.latitude}, ${position.longitude}');

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }

      String imageUrl = '';
      if (widget.capturedImage is File) {
        print('🗺️ Uploading image to Cloudinary...');
        imageUrl = await _uploadImageToCloudinary(widget.capturedImage as File);
        print('🗺️ Image URL after upload: $imageUrl');
      } else {
        print('⚠️ Captured image is not a File: ${widget.capturedImage.runtimeType}');
      }

      print('🗺️ Saving to Firestore...');
      print('🗺️ Data to save: {');
      print('  latitude: ${position.latitude},');
      print('  longitude: ${position.longitude},');
      print('  userId: guest_user,');
      print('  seaweed: { name: $seaweedName, confidence: $confidence, imageUrl: $imageUrl }');
      print('}');

      await _firestore.collection('map_points').add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'userId': 'guest_user',
        'createdAt': FieldValue.serverTimestamp(),
        'seaweeds': [
          {
            'name': seaweedName,
            'confidence': confidence,
            'imageUrl': imageUrl,
            'uploadedAt': DateTime.now().millisecondsSinceEpoch,
          }
        ],
      });

      print('✅ Firestore save successful!');

      if (!mounted) return;
      setState(() {
        _isSavingToMap = false;
        _mapSaveStatus = 'Saved to the seaweed map.';
      });
    } catch (e, st) {
      print('❌ Map save error: $e');
      print('❌ Stack trace: $st');
      
      if (!mounted) return;
      setState(() {
        _isSavingToMap = false;
        _mapSaveStatus = 'Unable to save to map: $e';
      });
    }
  }

  Future<void> _saveResultToDeviceHistory() async {
    try {
      final status = _getHistoryStatus();
      final imageData = await _encodeImageForHistory();
      final entry = {
        'name': seaweedName,
        'date': _formatDateTime(DateTime.now()),
        'status': status,
        'emoji': '🌿',
        'confidence': confidence,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'imageData': imageData,
      };

      final prefs = await SharedPreferences.getInstance();
      final storedHistory = prefs.getStringList('device_scan_history') ?? [];
      final history = storedHistory
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .toList();

      history.add(entry);
      history.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));

      final trimmedHistory = history.take(100).toList();
      await prefs.setStringList(
        'device_scan_history',
        trimmedHistory.map((item) => jsonEncode(item)).toList(),
      );

      print('💾 Saved scan result to device history');
    } catch (e) {
      print('❌ Unable to save device history: $e');
    }
  }

  Future<String?> _encodeImageForHistory() async {
    try {
      if (widget.capturedImage is File) {
        final file = widget.capturedImage as File;
        if (await file.exists()) {
          return base64Encode(await file.readAsBytes());
        }
      } else if (widget.capturedImage is String) {
        final file = File(widget.capturedImage as String);
        if (await file.exists()) {
          return base64Encode(await file.readAsBytes());
        }
      }
    } catch (e) {
      print('❌ Unable to encode image for history: $e');
    }

    return null;
  }

  String _getHistoryStatus() {
    if (seaweedName.trim().toLowerCase() == 'unrecognized') {
      return 'Unidentified';
    }

    final label = _getEdibilityLabel();
    if (label == 'Edible' || label == 'Not edible') {
      return label;
    }
    return 'Unidentified';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    final month = <int, String>{
      1: 'Jan',
      2: 'Feb',
      3: 'Mar',
      4: 'Apr',
      5: 'May',
      6: 'Jun',
      7: 'Jul',
      8: 'Aug',
      9: 'Sep',
      10: 'Oct',
      11: 'Nov',
      12: 'Dec',
    }[date.month];

    return '$month ${date.day}, ${date.year} $hour:$minute $suffix';
  }

  Future<String> _uploadImageToCloudinary(File imageFile) async {
    try {
      const uploadPreset = 'seaweeds_identifier';
      const cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dkvhqzo31/image/upload';

      print('📤 Starting Cloudinary upload for: ${imageFile.path}');
      print('📤 File exists: ${await imageFile.exists()}');
      print('📤 File size: ${await imageFile.length()} bytes');

      final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.fields['public_id'] = 'seaweeds/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      print('📤 Sending request to Cloudinary...');
      final response = await request.send().timeout(const Duration(minutes: 2));
      
      print('📤 Cloudinary response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        print('❌ Cloudinary error body: $errorBody');
        throw Exception('Cloudinary upload failed with status ${response.statusCode}: $errorBody');
      }

      final responseBody = await response.stream.bytesToString();
      print('📤 Cloudinary response: $responseBody');
      
      final responseData = jsonDecode(responseBody);
      final imageUrl = responseData['secure_url'] as String?;
      
      if (imageUrl == null || imageUrl.isEmpty) {
        print('⚠️ Cloudinary returned empty URL');
        return '';
      }
      
      print('✅ Cloudinary upload successful: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('❌ Cloudinary upload error: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Circular image result
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0CA8B3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0CA8B3).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(90),
                      child: _buildImageDisplay(),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Seaweed name with label
                  Text(
                    'Result: $seaweedName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Edibility badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: 'Status: ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: _getEdibilityLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getEdibilityLabel() == 'Edible'
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFF5252),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Prediction Probabilities (if available)
                  if (widget.prediction != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Prediction Scores',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.prediction!.probabilities.entries.map((e) {
                            final percentage = e.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      e.key,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 5,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percentage / 100,
                                        minHeight: 6,
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          e.key == widget.prediction!.prediction
                                              ? const Color(0xFF0CA8B3)
                                              : Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white60,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Cleaning Process section (only show if result is recognized)
                    if (seaweedName.trim().toLowerCase() != 'unrecognized')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Cleaning Process',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => RecommendedDishesScreen(
                                          speciesName: seaweedName,
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    'Recommended Recipes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildCleaningProcess(),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shared location map',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isSavingToMap)
                          const Text(
                            'Saving your current location to the shared map...',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          )
                        else if (_mapSaveStatus != null)
                          Text(
                            _mapSaveStatus!,
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          )
                        else
                          const Text(
                            'Your location is ready to be shared with other users.',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        const SizedBox(height: 10),
                        if (_userLocation != null)
                          SizedBox(
                            height: 180,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FlutterMap(
                                options: MapOptions(
                                  center: _userLocation!,
                                  zoom: 14.0,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _userLocation!,
                                        builder: (context) => const Icon(
                                          Icons.location_on,
                                          color: Color(0xFF0CA8B3),
                                          size: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Back to Home button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _backToHome,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Scan again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getEdibilityLabel() {
    // New rule: use confidence to determine status.
    // If confidence is greater than 60 => Edible, otherwise Unidentified.
    if (confidence > 60) {
      return 'Edible';
    }
    return 'Unidentified';
  }

  // Returns a list of cleaning steps for the predicted species (or empty if unknown)
  List<String> _getCleaningSteps() {
    final predicted = (widget.prediction?.prediction ?? seaweedName).trim().toLowerCase();

    if (predicted == 'caulerpa lentilifera' || predicted == 'caulerpa lentillifera') {
      return [
        'Pick and Sort: Look through the green grape-like clusters and pull out small rocks, tiny shells, or bits of other plants.',
        'First Wash: Rinse the sea grapes gently in a bowl of clean, cool tap water to remove dirt and extra salt.',
        'Ice Bath: Put them in ice-cold water for 3 minutes to make them crisp and take away the strong fishy smell.',
        'Drain: Take them out, drain all the water, and eat or serve them fresh right away. Do not use hot heat',
      ];
    }

    if (predicted == 'caulerpa sertularioides') {
      return [
        'Check and Sort: Pick out any loose sand, tiny sea bugs, or trash caught in the fine feather branches.',
        'Rinse Well: Put the fronds in a bowl of clean water. Swish them gently with your hands to drop the sand to the bottom.',
        'Change Water: Lift the seaweed out into a new bowl of clean water. Repeat this until no sand is left at the bottom of the bowl.',
        'Drain: Shake off extra water. It is now ready to eat raw in salads or for light cooking.',
      ];
    }

    if (predicted == 'kappaphycus') {
      return [
        'Clean Debris: Remove bits of plastic rope, wood, or small stones stuck to the thick branches.',
        'Wash Dirt: Rinse the whole clumps under running clean tap water or soak them in a large basin to wash away mud and salt.',
        'Blanch (Optional): If it is fresh, dip it in hot water (70°C) for 60 seconds to clean it deeper and make it softer for food use.',
        'Drain: Let the water drip off completely before cutting or adding it to your recipe.',
      ];
    }

    if (predicted == 'sargassum muticum') {
      return [
        'Sort Leaves: Pick out older, hard stems and any tiny sea animals hiding in the thick branches.',
        'Rinse and Soak: Wash the brown pieces well in clean water, then soak them in warm water for 15 to 30 minutes to clean out extra salt and reduce natural compounds.',
        'Blanch: Boil the seaweed in fresh unsalted water for 2 to 5 minutes until it changes to a bright color and gets tender.',
        'Cool Down: Drain the hot water and rinse with cold water before chopping.',
      ];
    }

    if (predicted == 'ulva lactuca') {
      return [
        'Separate Leaves: Spread out the thin green sheets in a large bowl of cold water.',
        'Shake Out Sand: Hold the sea lettuce under water and shake it gently so hidden sand falls into the bowl.',
        'Move to New Bowl: Move the clean leaves into a second bowl of fresh water. Repeat until the water stays clear and clean.',
        'Drain: Squeeze the leaves gently with your hands to get rid of extra water. It is ready for soups or salads.',
      ];
    }

    return [];
  }

  Widget _buildCleaningProcess() {
    final steps = _getCleaningSteps();
    if (steps.isEmpty) {
      return const Text(
        'No cleaning instructions available for this result.',
        style: TextStyle(fontSize: 12, color: Colors.white70),
        textAlign: TextAlign.justify,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((s) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '• $s',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.justify,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageDisplay() {
    try {
      if (widget.capturedImage is File) {
        final file = widget.capturedImage as File;
        print('📋 Displaying image from File: ${file.path}');
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading image: $error');
            return Container(
              color: Colors.white.withOpacity(0.1),
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white.withOpacity(0.5),
                size: 80,
              ),
            );
          },
        );
      } else if (widget.capturedImage is String) {
        final path = widget.capturedImage as String;
        print('📋 Displaying image from path string: $path');
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading image from path: $error');
            return Container(
              color: Colors.white.withOpacity(0.1),
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white.withOpacity(0.5),
                size: 80,
              ),
            );
          },
        );
      }
    } catch (e) {
      print('❌ Exception displaying image: $e');
    }
    
    return Container(
      color: Colors.white.withOpacity(0.1),
      child: Icon(
        Icons.image_outlined,
        color: Colors.white.withOpacity(0.5),
        size: 80,
      ),
    );
  }



  void _backToHome() {
    // Pop all routes until we reach the root (ScanScreen)
    // The ScanScreen will detect app resume and reinitialize camera
    Navigator.of(context).popUntil((route) {
      print('🔙 Popping route: ${route.settings.name ?? 'unknown'}');
      return route.isFirst;
    });
  }
}

// Full-screen map screen for selecting location
class FullScreenMapScreen extends StatefulWidget {
  const FullScreenMapScreen({super.key});

  @override
  State<FullScreenMapScreen> createState() => _FullScreenMapScreenState();
}

class _FullScreenMapScreenState extends State<FullScreenMapScreen> {
  late MapController mapController;
  late LatLng selectedLocation = LatLng(11.5740, 124.5745);

  @override
  void initState() {
    super.initState();
    mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full map
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: selectedLocation,
              zoom: 11.0,
              onTap: (tapPosition, point) {
                setState(() {
                  selectedLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: selectedLocation,
                    builder: (context) => Icon(
                      Icons.location_on,
                      color: Colors.red.shade700,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Top bar with back button and title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Select Location in Biliran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF0CA8B3),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selected Location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '${selectedLocation.latitude.toStringAsFixed(4)}, ${selectedLocation.longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, selectedLocation);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Location saved: ${selectedLocation.latitude.toStringAsFixed(4)}, ${selectedLocation.longitude.toStringAsFixed(4)}',
                              ),
                              backgroundColor: const Color(0xFF0CA8B3),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0CA8B3),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }                                                                                                                                                          
}
