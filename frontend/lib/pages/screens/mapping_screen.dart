// ignore_for_file: use_build_context_synchronously, constant_identifier_names, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/navigation_service.dart';

class MappingScreen extends StatefulWidget {
  const MappingScreen({super.key});

  @override
  State<MappingScreen> createState() => _MappingScreenState(); 
}

class _MappingScreenState extends State<MappingScreen> { 
  static const String CLOUDINARY_UPLOAD_PRESET = 'seaweeds_identifier';
  static const String CLOUDINARY_API_URL = 'https://api.cloudinary.com/v1_1/dkvhqzo31/image/upload';
  final List<Marker> _markers = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSearching = false;
  List<BiliranLocation> _searchSuggestions = [];

  // Seaweed upload state
  final List<File> _selectedSeaweedImages = [];
  final List<String> _seaweedNames = [];
  LatLng? _pendingLocationPoint;
  String? _editingLocationId; // Track which location we're editing

  // Navigation state
  final NavigationService _navigationService = NavigationService();
  LatLng? _userLocation;
  List<RouteInfo> _currentRoutes = [];
  List<Polyline> _routePolylines = [];
  bool _isLoadingRoute = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mapPointsSubscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedMapDocs;
  bool _hasLoadedCachedMarkers = false;

  // Biliran Province bounding box (Lat/Lon boundaries)
  static const double BILIRAN_MIN_LAT = 11.30;
  static const double BILIRAN_MAX_LAT = 11.80;
  static const double BILIRAN_MIN_LON = 124.20;
  static const double BILIRAN_MAX_LON = 124.90;

  // Comprehensive Biliran location database
  final List<BiliranLocation> _biliraniLocations = [
    // Municipalities
    BiliranLocation(
      name: 'Naval',
      municipality: 'Naval',
      type: 'Municipality',
      lat: 11.5833,
      lon: 124.4500,
      zoomLevel: 14,
    ),
    BiliranLocation(
      name: 'Caibiran',
      municipality: 'Caibiran',
      type: 'Municipality',
      lat: 11.5667,
      lon: 124.6167,
      zoomLevel: 14,
    ),
    BiliranLocation(
      name: 'Culaba',
      municipality: 'Culaba',
      type: 'Municipality',
      lat: 11.4667,
      lon: 124.6000,
      zoomLevel: 14,
    ),
    BiliranLocation(
      name: 'Maripipi',
      municipality: 'Maripipi',
      type: 'Municipality',
      lat: 11.3500,
      lon: 124.5500,
      zoomLevel: 14,
    ),
    BiliranLocation(
      name: 'Almeria',
      municipality: 'Almeria',
      type: 'Municipality',
      lat: 11.4833,
      lon: 124.4667,
      zoomLevel: 14,
    ),
    BiliranLocation(
      name: 'Biliran Town',
      municipality: 'Biliran',
      type: 'Municipality',
      lat: 11.5775,
      lon: 124.5261,
      zoomLevel: 14,
    ),

    // Major Barangays and Notable Locations
    BiliranLocation(
      name: 'Tinago Falls',
      municipality: 'Caibiran',
      type: 'Landmark',
      lat: 11.5700,
      lon: 124.6300,
      zoomLevel: 16,
    ),
    BiliranLocation(
      name: 'Higatangan Island',
      municipality: 'Maripipi',
      type: 'Landmark',
      lat: 11.3200,
      lon: 124.5000,
      zoomLevel: 15,
    ),
    BiliranLocation(
      name: 'Barangay Caraycaray',
      municipality: 'Almeria',
      type: 'Barangay',
      lat: 11.4750,
      lon: 124.4700,
      zoomLevel: 15,
    ),
    BiliranLocation(
      name: 'Barangay Cabucgayan',
      municipality: 'Caibiran',
      type: 'Barangay',
      lat: 11.5700,
      lon: 124.6200,
      zoomLevel: 15,
    ),
    BiliranLocation(
      name: 'Barangay Proper',
      municipality: 'Naval',
      type: 'Barangay',
      lat: 11.5850,
      lon: 124.4520,
      zoomLevel: 15,
    ),
    BiliranLocation(
      name: 'Barangay Cibulao',
      municipality: 'Biliran',
      type: 'Barangay',
      lat: 11.5800,
      lon: 124.5300,
      zoomLevel: 15,
    ),
    BiliranLocation(
      name: 'Paras Beach',
      municipality: 'Almeria',
      type: 'Beach',
      lat: 11.4900,
      lon: 124.4800,
      zoomLevel: 16,
    ),
    BiliranLocation(
      name: 'Dakong Beach',
      municipality: 'Caibiran',
      type: 'Beach',
      lat: 11.5650,
      lon: 124.6350,
      zoomLevel: 16,
    ),
    BiliranLocation(
      name: 'Poro Point',
      municipality: 'Naval',
      type: 'Landmark',
      lat: 11.5900,
      lon: 124.4300,
      zoomLevel: 15,
    ),
  ];


  @override
  void initState() {
    super.initState();
    debugPrint('MappingScreen initState - loading markers');
    _listenToMapPoints();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _mapPointsSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _searchSuggestions = [];
      } else {
        _updateSearchSuggestions(_searchController.text);
      }
    });
  }

  void _updateSearchSuggestions(String query) {
    if (query.isEmpty) {
      _searchSuggestions = [];
      return;
    }

    final searchQuery = query.toLowerCase().trim();
    final matches = <BiliranLocation>[];

    // Score-based matching system
    for (final location in _biliraniLocations) {
      final score = _calculateMatchScore(location, searchQuery);
      if (score > 0) {
        matches.add(location);
      }
    }

    // Sort by score (highest first)
    matches.sort((a, b) {
      return _calculateMatchScore(b, searchQuery)
          .compareTo(_calculateMatchScore(a, searchQuery));
    });

    _searchSuggestions = matches.take(8).toList();
  }

  int _calculateMatchScore(BiliranLocation location, String query) {
    int score = 0;
    final name = location.name.toLowerCase();
    final municipality = location.municipality.toLowerCase();

    // Exact match: highest priority
    if (name == query) return 1000;
    if (municipality == query) return 900;

    // Starts with query
    if (name.startsWith(query)) score += 500;
    if (municipality.startsWith(query)) score += 450;

    // Contains query
    if (name.contains(query)) score += 200;
    if (municipality.contains(query)) score += 150;

    // Fuzzy match (has all chars in order)
    if (_isFuzzyMatch(name, query)) score += 100;

    // Bonus for exact type matches
    if (query.contains('barangay') && location.type == 'Barangay') {
      score += 300;
    }

    return score;
  }

  bool _isFuzzyMatch(String str, String query) {
    int queryIndex = 0;
    for (int i = 0; i < str.length && queryIndex < query.length; i++) {
      if (str[i] == query[queryIndex]) {
        queryIndex++;
      }
    }
    return queryIndex == query.length;
  }

  Future<void> _loadMarkers() async {
    if (!_hasLoadedCachedMarkers && _cachedMapDocs != null) {
      _applyMarkers(_cachedMapDocs!);
      _hasLoadedCachedMarkers = true;
    }

    try {
      final snapshot = await _firestore.collection('map_points').get();
      debugPrint('Loading ${snapshot.docs.length} map points from Firestore');
      _cachedMapDocs = snapshot.docs;
      _applyMarkers(snapshot.docs);
    } catch (e) {
      debugPrint('Error loading markers: $e');
    }
  }

  void _listenToMapPoints() {
    _mapPointsSubscription?.cancel();
    _mapPointsSubscription = _firestore.collection('map_points').snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        debugPrint('Realtime map update received: ${snapshot.docs.length} docs');
        _cachedMapDocs = snapshot.docs;
        _applyMarkers(snapshot.docs);
      },
      onError: (error) {
        debugPrint('Error listening to map points: $error');
      },
    );
  }

  void _applyMarkers(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (!mounted) return;

    setState(() {
      _markers.clear();

      for (final doc in docs) {
        try {
          final data = doc.data();
          final lat = _parseCoordinate(data['latitude']);
          final lon = _parseCoordinate(data['longitude']);
          final seaweeds = _extractSeaweeds(data['seaweeds']);
          final visibleSeaweeds = seaweeds.where(_shouldDisplaySeaweed).toList();
          final docId = doc.id;

          debugPrint('Document ID: ${doc.id}, lat=$lat, lon=$lon, seaweeds=${seaweeds.length}, visible=${visibleSeaweeds.length}');

          if (lat == null || lon == null || visibleSeaweeds.isEmpty) {
            continue;
          }

          final seaweed = visibleSeaweeds.first;
          final imageUrl = _readImageUrl(seaweed);

          _markers.add(
            Marker(
              point: LatLng(lat, lon),
              width: 50,
              height: 50,
              builder: (ctx) => GestureDetector(
                onTap: () => _showSeaweedDetails(LatLng(lat, lon), seaweeds),
                onDoubleTap: () => _editSeaweedsForLocation(docId, LatLng(lat, lon)),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Image load error: $error');
                              return const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              );
                            },
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
              ),
            ),
          );
        } catch (docError) {
          debugPrint('Error processing document ${doc.id}: $docError');
        }
      }

      debugPrint('Total markers loaded: ${_markers.length}');
    });
  }

  double? _parseCoordinate(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  List<Map<String, dynamic>> _extractSeaweeds(dynamic rawSeaweeds) {
    if (rawSeaweeds is List) {
      return rawSeaweeds.whereType<Map>().map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();
    }
    return [];
  }

  bool _shouldDisplaySeaweed(Map<String, dynamic> seaweed) {
    final confidence = seaweed['confidence'];
    if (confidence is num) {
      return confidence > 70;
    }
    return true;
  }

  String? _readImageUrl(Map<String, dynamic> seaweed) {
    final imageUrl = seaweed['imageUrl'];
    if (imageUrl is String) {
      return imageUrl;
    }
    return null;
  }

  bool _isWithinBiliran(double lat, double lon) {
    return lat >= BILIRAN_MIN_LAT &&
        lat <= BILIRAN_MAX_LAT &&
        lon >= BILIRAN_MIN_LON &&
        lon <= BILIRAN_MAX_LON;
  }

  Future<void> _searchLocation(BiliranLocation? location,
      [String? customQuery]) async {
    final query = customQuery ?? _searchController.text;

    if (query.isEmpty && location == null) return;

    setState(() => _isSearching = true);

    try {
      LatLng? targetPoint;
      double? targetZoom;
      String displayName = '';

      // If location provided from suggestions, use it
      if (location != null) {
        targetPoint = LatLng(location.lat, location.lon);
        targetZoom = location.zoomLevel.toDouble();
        displayName = location.name;
      } else {
        // Try to geocode the query using Nominatim
        final geocodedPoint = await _geocodeLocation(query);
        if (geocodedPoint != null) {
          targetPoint = geocodedPoint['point'];
          targetZoom = geocodedPoint['zoom'];
          displayName = geocodedPoint['name'];
        }
      }

      if (targetPoint != null && _isWithinBiliran(targetPoint.latitude, targetPoint.longitude)) {
        // Animate to the location
        _mapController.move(targetPoint, targetZoom ?? 15.0);


        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found: $displayName'),
              backgroundColor: const Color(0xFF0CA8B3),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Clear search and suggestions
        setState(() {
          _searchSuggestions = [];
        });
      } else if (targetPoint != null) {
        // Result outside Biliran
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Result is outside Biliran. Searching within Biliran only...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // No result found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location not found in Biliran'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<Map<String, dynamic>?> _geocodeLocation(String query) async {
    try {
      // Append Biliran context
      final searchQuery = '$query, Biliran, Philippines';
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(searchQuery)}&format=json&limit=5',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'BiliranSeaweedApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;

        if (results.isEmpty) return null;

        // Filter results within Biliran bounds and find the best match
        for (final result in results) {
          final lat = double.tryParse(result['lat'].toString());
          final lon = double.tryParse(result['lon'].toString());
          final name = result['display_name'] ?? 'Location';

          if (lat != null && lon != null) {
            final latLng = LatLng(lat, lon);

            // Check if result is within Biliran
            if (_isWithinBiliran(lat, lon)) {
              // Determine zoom level based on result type
              double zoomLevel = 15.0;
              final addressType = result['address_type'] ?? '';
              if (addressType.contains('municipality') ||
                  addressType.contains('city')) {
                zoomLevel = 14.0;
              } else if (addressType.contains('village') ||
                  addressType.contains('hamlet')) {
                zoomLevel = 16.0;
              }

              return {
                'point': latLng,
                'zoom': zoomLevel,
                'name': name,
              };
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }

    return null;
  }

  Future<void> _handleRefresh() async {
    await _loadMarkers();
  }

  void _editSeaweedsForLocation(String docId, LatLng location) {
    setState(() {
      _editingLocationId = docId;
      _pendingLocationPoint = location;
      _selectedSeaweedImages.clear();
      _seaweedNames.clear();
    });
    _showSeaweedUploadModal(isEditing: true);
  }

  Future<void> _uploadSeaweedsAndLocation() async {
  debugPrint('=== Upload start ===');
  debugPrint('auth uid: guest_user');
  debugPrint('editingLocationId: $_editingLocationId');
  debugPrint('pendingLocationPoint: $_pendingLocationPoint');
  debugPrint('selected count: ${_selectedSeaweedImages.length}');

  if (_selectedSeaweedImages.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select at least one seaweed image')),
    );
    return;
  }

  if (_seaweedNames.any((name) => name.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter names for all seaweeds')),
    );
    return;
  }

  try {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0CA8B3)),
          ),
        ),
      );
    }

    // Upload images to Cloudinary and create seaweed data
    List<Map<String, dynamic>> seaweedsList = [];
    
    for (int i = 0; i < _selectedSeaweedImages.length; i++) {
      try {
        final imageFile = _selectedSeaweedImages[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${timestamp}_${i}_${imageFile.path.split('/').last}';
        
        debugPrint('Uploading image $i to Cloudinary: $fileName');
        debugPrint('File size: ${imageFile.lengthSync()} bytes');
        
        // Upload to Cloudinary using HTTP
        final request = http.MultipartRequest('POST', Uri.parse(CLOUDINARY_API_URL));
        request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
        request.fields['public_id'] = 'seaweeds/$fileName';
        request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );
        
        debugPrint('Sending request to Cloudinary...');
        final response = await request.send().timeout(const Duration(minutes: 2));
        
        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          final responseData = jsonDecode(responseBody);
          final imageUrl = responseData['secure_url'] as String?;

          if (imageUrl == null || imageUrl.isEmpty) {
            throw Exception('Cloudinary response missing secure_url: $responseBody');
          }

          debugPrint('Successfully uploaded image $i: $imageUrl');

          seaweedsList.add({
            'name': _seaweedNames[i],
            'imageUrl': imageUrl,
            'uploadedAt': DateTime.now().millisecondsSinceEpoch,
          });
        } else {
          final responseBody = await response.stream.bytesToString();
          throw Exception(
            'Upload failed with status ${response.statusCode}. Body: $responseBody',
          );
        }
      } catch (uploadError) {
        debugPrint('Error uploading image $i: $uploadError');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload Error: $uploadError'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }
    }

    if (_editingLocationId != null) {
      await _firestore.collection('map_points').doc(_editingLocationId).update({
        'seaweeds': FieldValue.arrayUnion(seaweedsList),
      });
    } else {
      await _firestore.collection('map_points').add({
        'latitude': _pendingLocationPoint!.latitude,
        'longitude': _pendingLocationPoint!.longitude,
        'userId': 'guest_user',
        'createdAt': FieldValue.serverTimestamp(),
        'seaweeds': seaweedsList,
      });
    }

    setState(() {
      _selectedSeaweedImages.clear();
      _seaweedNames.clear();
      _pendingLocationPoint = null;
      _editingLocationId = null;
    });

    await _loadMarkers();

    if (mounted) {
      // Close the progress dialog
      Navigator.pop(context);
      // Close the modal
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${seaweedsList.length} seaweeds uploaded successfully'),
        backgroundColor: const Color(0xFF0CA8B3),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e, st) {
    debugPrint('Firestore/upload ERROR: $e');
    debugPrint('Stacktrace: $st');
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

  
  void _showSeaweedDetails(LatLng location, List<dynamic> seaweeds) {
    // Zoom to location
    _mapController.move(location, 16.0);

    // Calculate distance from user if available
    String distanceText = '';
    if (_userLocation != null) {
      final distance = _navigationService.calculateDistance(_userLocation!, location);
      distanceText = _navigationService.formatDistance(distance);
    }

    // Show bottom sheet with seaweed carousel
    showModalBottomSheet(
      context: context,
      builder: (context) => _SeaweedDetailsBottomSheet(
        location: location,
        distanceText: distanceText,
        navigationService: _navigationService,
        userLocation: _userLocation,
        isLoadingRoute: _isLoadingRoute,
        onNavigate: () {
          Navigator.pop(context); // Close bottom sheet
          _initiateNavigation(location);
        },
        firestore: _firestore,
      ),
    );
  }

  /// Initiate navigation to a destination
  Future<void> _initiateNavigation(LatLng destination) async {
    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // Check if location service is enabled
      bool isServiceEnabled = await _navigationService.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (!mounted) return;
        _showLocationDisabledDialog();
        setState(() => _isLoadingRoute = false);
        return;
      }

      // Request location permission
      bool hasPermission = await _navigationService.requestLocationPermission();
      if (!hasPermission) {
        if (!mounted) return;
        _showPermissionDeniedDialog();
        setState(() => _isLoadingRoute = false);
        return;
      }

      // Get user's current location
      LatLng? userLocation = await _navigationService.getCurrentLocation();
      if (userLocation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not retrieve your location'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingRoute = false);
        return;
      }

      setState(() => _userLocation = userLocation);

      // Calculate routes
      List<RouteInfo> routes = await _navigationService.calculateRoutes(
        userLocation,
        destination,
      );

      if (routes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not calculate route'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingRoute = false);
        return;
      }

      // Create polylines for routes
      List<Polyline> polylines = [];
      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        polylines.add(
          Polyline(
            points: route.coordinates,
            color: route.isBest ? const Color(0xFF0CA8B3) : Colors.grey,
            strokeWidth: route.isBest ? 4 : 2,
          ),
        );
      }

      // Update map with routes
      setState(() {
        _currentRoutes = routes;
        _routePolylines = polylines;
        _isLoadingRoute = false;
      });

      // Defer zoom animation until after the frame is rendered to avoid flickering
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _zoomToFitRoute(userLocation, destination);
      });

      // Show route summary snackbar
      if (mounted && routes.isNotEmpty) {
        final bestRoute = routes.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route: ${_navigationService.formatDistance(bestRoute.distance)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Time: ${_navigationService.formatDuration(bestRoute.duration)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (routes.length > 1)
                  Text(
                    '${routes.length} routes',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            backgroundColor: const Color(0xFF0CA8B3),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoadingRoute = false);
    }
  }

  /// Zoom map to fit the entire route
  void _zoomToFitRoute(LatLng start, LatLng end) {
    // Calculate bounds with expanded padding for smooth animation
    final minLat = start.latitude < end.latitude ? start.latitude : end.latitude;
    final maxLat = start.latitude > end.latitude ? start.latitude : end.latitude;
    final minLon = start.longitude < end.longitude ? start.longitude : end.longitude;
    final maxLon = start.longitude > end.longitude ? start.longitude : end.longitude;

    final bounds = LatLngBounds(
      LatLng(minLat, minLon),
      LatLng(maxLat, maxLon),
    );

    _mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(
        padding: EdgeInsets.all(120),
      ),
    );
  }

  /// Show dialog for disabled location service
  void _showLocationDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable location services to use navigation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for permission denied
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is required to calculate and display routes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }


  double _estimateTravelTimeMinutes(double distanceKm, double averageSpeedKmh) {
    if (averageSpeedKmh <= 0) {
      return 0;
    }

    return (distanceKm / averageSpeedKmh) * 60;
  }

  Widget _buildRouteSummaryCard() {
    if (_currentRoutes.isEmpty) {
      return const SizedBox.shrink();
    }

    final bestRoute = _currentRoutes.first;
    final motorcycleMinutes = _estimateTravelTimeMinutes(bestRoute.distance, 40);
    final busMinutes = _estimateTravelTimeMinutes(bestRoute.distance, 20);

    return Positioned(
      top: 90,
      left: 16,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Route Summary',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0CA8B3),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Distance: ${_navigationService.formatDistance(bestRoute.distance)}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Motorcycle: ${_navigationService.formatDuration(motorcycleMinutes)}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bus: ${_navigationService.formatDuration(busMinutes)}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSeaweedUploadModal({bool isEditing = false}) {
    showDialog(
      context: context,
      builder: (context) => _SeaweedUploadModalDialog(
        isEditing: isEditing,
        selectedImages: _selectedSeaweedImages,
        seaweedNames: _seaweedNames,
        onImagePicked: () async {
          final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            setState(() {
              _selectedSeaweedImages.add(File(image.path));
              _seaweedNames.add('');
            });
          }
        },
        onImageRemoved: (index) {
          setState(() {
            _selectedSeaweedImages.removeAt(index);
            _seaweedNames.removeAt(index);
          });
        },
        onNameChanged: (index, name) {
          setState(() {
            _seaweedNames[index] = name;
          });
        },
        onUpload: _uploadSeaweedsAndLocation,
        onCancel: () {
          setState(() {
            _selectedSeaweedImages.clear();
            _seaweedNames.clear();
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
          // Full-screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(11.5775, 124.5261), // Biliran center
              zoom: 11.0,
              maxZoom: 18.0,
              minZoom: 8.0,
              interactiveFlags: InteractiveFlag.drag |
                  InteractiveFlag.flingAnimation |
                  InteractiveFlag.pinchMove |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.rotate,
              onTap: (tapPosition, point) async {
                // Restrict to Biliran bounds
                if (!_isWithinBiliran(point.latitude, point.longitude)) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'You can only add points within Biliran province',
                      ),
                    ),
                  );
                  return;
                }

                // Store the pending location and show upload modal for new location
                setState(() {
                  _editingLocationId = null;
                  _pendingLocationPoint = point;
                  _selectedSeaweedImages.clear();
                  _seaweedNames.clear();
                });
                _showSeaweedUploadModal(isEditing: false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.frontend',
              ),
              PolylineLayer(polylines: _routePolylines),
              MarkerLayer(markers: _markers),
            ],
          ),

          if (_isLoadingRoute)
            Positioned(
              top: 96,
              left: 16,
              right: 16,
              child: SafeArea(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0CA8B3),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Calculating route...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_currentRoutes.isNotEmpty) _buildRouteSummaryCard(),

          // Search bar with suggestions dropdown
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (value) {
                        _searchLocation(null, value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search location in Biliran...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 14,
                        ),
                        prefixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF0CA8B3),
                                    ),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF0CA8B3),
                              ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchSuggestions = []);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  // Suggestions dropdown
                  if (_searchSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _searchSuggestions.length,
                        itemBuilder: (context, index) {
                          final location = _searchSuggestions[index];
                          return ListTile(
                            leading: Icon(
                              _getIconForType(location.type),
                              color: const Color(0xFF0CA8B3),
                            ),
                            title: Text(location.name),
                            subtitle:
                                Text('${location.municipality} • ${location.type}'),
                            onTap: () {
                              _searchController.text = location.name;
                              _searchLocation(location);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Zoom controls
          Positioned(
            right: 10,
            bottom: 156,
            child: Column(
              children: [
                // Zoom in button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: Color(0xFF0CA8B3),
                    ),
                    onPressed: () {
                      _mapController.move(
                        _mapController.center,
                        _mapController.zoom + 1,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Zoom out button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.remove,
                      color: Color(0xFF0CA8B3),
                    ),
                    onPressed: () {
                      _mapController.move(
                        _mapController.center,
                        _mapController.zoom - 1,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Location button
          Positioned(
            right: 10,
            bottom: 100,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.gps_fixed_rounded,
                  color: Color(0xFF0CA8B3),
                ),
                onPressed: () {
                  // Return to Biliran center
                  _mapController.move(LatLng(11.5775, 124.5261), 11.0);
                },
              ),
            ),
          ),
        ],
      ),
    ),
    )
      )
    );

  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Municipality':
        return Icons.location_city;
      case 'Barangay':
        return Icons.home;
      case 'Landmark':
        return Icons.attractions;
      case 'Beach':
        return Icons.water;
      default:
        return Icons.location_on;
    }
  }
}

// ignore: unused_element
class _RouteSummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _RouteSummaryItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// Seaweed Upload Modal Dialog Widget
class _SeaweedUploadModalDialog extends StatefulWidget {
  final bool isEditing;
  final List<File> selectedImages;
  final List<String> seaweedNames;
  final Future<void> Function() onImagePicked;
  final Function(int) onImageRemoved;
  final Function(int, String) onNameChanged;
  final VoidCallback onUpload;
  final VoidCallback onCancel;

  const _SeaweedUploadModalDialog({
    required this.isEditing,
    required this.selectedImages,
    required this.seaweedNames,
    required this.onImagePicked,
    required this.onImageRemoved,
    required this.onNameChanged,
    required this.onUpload,
    required this.onCancel,
  });

  @override
  State<_SeaweedUploadModalDialog> createState() => _SeaweedUploadModalDialogState();
}

class _SeaweedUploadModalDialogState extends State<_SeaweedUploadModalDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.isEditing ? 'Add More Seaweeds' : 'Add Seaweeds'),
          if (widget.selectedImages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0CA8B3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.selectedImages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Empty state
              if (widget.selectedImages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No images selected yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Tap the button below to add seaweed images',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Image list with cards
                Column(
                  children: List.generate(
                    widget.selectedImages.length,
                    (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Image thumbnail with badge
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      widget.selectedImages[index],
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0CA8B3),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Name input field
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Seaweed #${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      onChanged: (value) {
                                        widget.onNameChanged(index, value);
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Enter name',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF0CA8B3),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Delete button
                              GestureDetector(
                                onTap: () {
                                  widget.onImageRemoved(index);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.red[400],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              // Add image button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await widget.onImagePicked();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add Another Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: const Color(0xFF0CA8B3),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(
                      color: Color(0xFF0CA8B3),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: widget.selectedImages.isEmpty ? null : widget.onUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0CA8B3),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: const Text(
            'Upload',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.all(16),
    );
  }
}




// Seaweed Details Bottom Sheet Widget
class _SeaweedDetailsBottomSheet extends StatefulWidget {
  final LatLng location;
  final String distanceText;
  final NavigationService navigationService;
  final LatLng? userLocation;
  final bool isLoadingRoute;
  final VoidCallback onNavigate;
  final FirebaseFirestore firestore;

  const _SeaweedDetailsBottomSheet({
    required this.location,
    required this.distanceText,
    required this.navigationService,
    required this.userLocation,
    required this.isLoadingRoute,
    required this.onNavigate,
    required this.firestore,
  });

  @override
  State<_SeaweedDetailsBottomSheet> createState() =>
      _SeaweedDetailsBottomSheetState();
}

class _SeaweedDetailsBottomSheetState extends State<_SeaweedDetailsBottomSheet> {
  late Future<List<Map<String, dynamic>>> _nearbySeaweedsFuture;

  @override
  void initState() {
    super.initState();
    _nearbySeaweedsFuture = _loadNearbySeaweeds();
  }

  Future<List<Map<String, dynamic>>> _loadNearbySeaweeds() async {
    try {
      final snapshot = await widget.firestore.collection('map_points').get();
      List<Map<String, dynamic>> allNearbySeaweeds = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'] as double?;
        final lon = data['longitude'] as double?;
        final seaweeds =
            (data['seaweeds'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        if (lat != null && lon != null && seaweeds.isNotEmpty) {
          final markerLocation = LatLng(lat, lon);

          // Calculate distance in meters
          final distanceKm = widget.navigationService.calculateDistance(
            widget.location,
            markerLocation,
          );
          final distanceMeters = distanceKm * 1000;

          // Check if within 50m radius
          if (distanceMeters <= 50) {
            for (final seaweed in seaweeds) {
              allNearbySeaweeds.add({
                ...seaweed,
                'distance': widget.navigationService.formatDistance(distanceKm),
                'distanceMeters': distanceMeters.toInt(),
              });
            }
          }
        }
      }

      // Sort by distance
      allNearbySeaweeds.sort((a, b) =>
          (a['distanceMeters'] as int)
              .compareTo(b['distanceMeters'] as int));

      return allNearbySeaweeds;
    } catch (e) {
      debugPrint('Error loading nearby seaweeds: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight * 0.38;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: availableHeight,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seaweeds in this area',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.distanceText.isNotEmpty)
                  Chip(
                    label: Text(widget.distanceText),
                    backgroundColor: const Color(0xFF0CA8B3).withOpacity(0.2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _nearbySeaweedsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF0CA8B3),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final nearbySeaweeds = snapshot.data ?? [];

                  if (nearbySeaweeds.isEmpty) {
                    return Center(
                      child: Text(
                        'No seaweeds found within 50m',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${nearbySeaweeds.length} seaweed${nearbySeaweeds.length > 1 ? 's' : ''} within 50m',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 170,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: nearbySeaweeds.length,
                          itemBuilder: (context, index) {
                            final seaweed = nearbySeaweeds[index];
                            final name = seaweed['name'] ?? 'Unknown';
                            final imageUrl = seaweed['imageUrl'] ?? '';
                            final distance = seaweed['distance'] as String?;

                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 110,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imageUrl,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.broken_image,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (distance != null &&
                                            distance.isNotEmpty)
                                          Positioned(
                                            bottom: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.black.withOpacity(0.7),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                distance,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isLoadingRoute ? null : widget.onNavigate,
                icon: widget.isLoadingRoute
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.95),
                          ),
                        ),
                      )
                    : const Icon(Icons.navigation),
                label: Text(
                  widget.isLoadingRoute
                      ? 'Calculating route...'
                      : 'Get Directions',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0CA8B3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

// Location data model
class BiliranLocation {
  final String name;
  final String municipality;
  final String type;
  final double lat;
  final double lon;
  final int zoomLevel;

  BiliranLocation({
    required this.name,
    required this.municipality,
    required this.type,
    required this.lat,
    required this.lon,
    required this.zoomLevel,
  });
}
