import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Route Service - Real route calculation using OSRM (free, no API key)
class RouteService {
  static final RouteService _instance = RouteService._();
  factory RouteService() => _instance;
  RouteService._();

  // OSRM Demo Server (for development - use your own for production)
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';

  /// Calculate route between two points
  /// Returns RouteResult with polyline, distance, and duration
  Future<RouteResult?> getRoute(LatLng from, LatLng to,
      {String profile = 'driving'}) async {
    try {
      final url = '$_osrmBaseUrl/route/v1/$profile/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=full&geometries=polyline';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Decode polyline
          final polyline = _decodePolyline(route['geometry']);

          return RouteResult(
            points: polyline,
            distanceMeters: (route['distance'] as num).toDouble(),
            durationSeconds: (route['duration'] as num).toDouble(),
          );
        }
      }

      return null;
    } catch (e) {
      print('Route calculation error: $e');
      return null;
    }
  }

  /// Get walking route (for driver coming to pickup)
  Future<RouteResult?> getWalkingRoute(LatLng from, LatLng to) async {
    return getRoute(from, to, profile: 'foot');
  }

  /// Get driving route
  Future<RouteResult?> getDrivingRoute(LatLng from, LatLng to) async {
    return getRoute(from, to, profile: 'driving');
  }

  /// Decode polyline string to list of LatLng
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Format distance for display
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Format duration for display
  String formatDuration(double seconds) {
    if (seconds < 60) {
      return '${seconds.round()} sec';
    } else if (seconds < 3600) {
      return '${(seconds / 60).round()} min';
    } else {
      final hours = (seconds / 3600).floor();
      final mins = ((seconds % 3600) / 60).round();
      return '$hours hr $mins min';
    }
  }
}

/// Route calculation result
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  String get formattedDuration {
    if (durationSeconds < 60) {
      return '${durationSeconds.round()} sec';
    } else if (durationSeconds < 3600) {
      return '${(durationSeconds / 60).round()} min';
    } else {
      final hours = (durationSeconds / 3600).floor();
      final mins = ((durationSeconds % 3600) / 60).round();
      return '$hours hr $mins min';
    }
  }
}
