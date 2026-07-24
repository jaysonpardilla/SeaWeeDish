import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteInfo {
  final List<LatLng> coordinates;
  final double distance; // in kilometers
  final double duration; // in minutes
  final bool isBest; // true if this is the fastest route

  RouteInfo({
    required this.coordinates,
    required this.distance,
    required this.duration,
    this.isBest = false,
  });
}

class NavigationService {
  static const String OSRM_API = 'https://router.project-osrm.org/route/v1/driving';

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current user location
  Future<LatLng?> getCurrentLocation() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied ||
          hasPermission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Calculate routes between two points using OSRM
  Future<List<RouteInfo>> calculateRoutes(
    LatLng start,
    LatLng destination,
  ) async {
    try {
      final url =
          '$OSRM_API/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?steps=true&geometries=geojson&overview=full&alternatives=true';

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final routes = json['routes'] as List;

        if (routes.isEmpty) return [];

        final List<RouteInfo> routeInfos = [];

        for (int i = 0; i < routes.length; i++) {
          final route = routes[i];
          final geometry = route['geometry']['coordinates'] as List;
          final distance = (route['distance'] as num).toDouble() / 1000; // Convert to km
          final duration = (route['duration'] as num).toDouble() / 60; // Convert to minutes

          // Decode the polyline coordinates
          final coordinates = geometry
              .map((coord) => LatLng(
                    (coord[1] as num).toDouble(),
                    (coord[0] as num).toDouble(),
                  ))
              .toList();

          routeInfos.add(
            RouteInfo(
              coordinates: coordinates,
              distance: distance,
              duration: duration,
              isBest: i == 0, // First route is the fastest
            ),
          );
        }

        return routeInfos;
      }
      return [];
    } catch (e) {
      print('Error calculating routes: $e');
      return [];
    }
  }

  /// Calculate distance between two points in kilometers
  double calculateDistance(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      start,
      end,
    );
  }

  /// Format distance for display
  String formatDistance(double kilometers) {
    if (kilometers < 1) {
      return '${(kilometers * 1000).toStringAsFixed(0)}m';
    }
    return '${kilometers.toStringAsFixed(2)}km';
  }

  /// Format duration for display
  String formatDuration(double minutes) {
    if (minutes < 1) {
      return '${(minutes * 60).toStringAsFixed(0)}s';
    }
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)}min';
    }
    final hours = minutes / 60;
    final mins = minutes % 60;
    return '${hours.toStringAsFixed(0)}h ${mins.toStringAsFixed(0)}m';
  }
}
