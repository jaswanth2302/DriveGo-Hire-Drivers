import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../cache/geo_cache.dart';

/// Distance Service
///
/// Calculates distances using Haversine formula (independent of map provider).
/// Used for pricing, driver matching, and ETA when API is unavailable.
final distanceServiceProvider = Provider((ref) => DistanceService());

class DistanceService {
  final GeoCache _cache = GeoCache();

  /// Calculate distance between two points (Haversine)
  double calculateDistance(LatLng from, LatLng to) {
    final cacheKey =
        'dist_${from.latitude}_${from.longitude}_${to.latitude}_${to.longitude}';

    final cached = _cache.getDistance(cacheKey);
    if (cached != null) return cached;

    final distance = _haversine(from, to);
    _cache.putDistance(cacheKey, distance);

    return distance;
  }

  /// Calculate total distance for a route
  double calculateRouteDistance(List<LatLng> points) {
    if (points.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += calculateDistance(points[i], points[i + 1]);
    }

    return total;
  }

  /// Find nearest point from a list
  int findNearestIndex(LatLng location, List<LatLng> points) {
    int nearestIndex = 0;
    double nearestDist = double.infinity;

    for (int i = 0; i < points.length; i++) {
      final dist = calculateDistance(location, points[i]);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  /// Find all points within radius
  List<int> findPointsWithinRadius(
    LatLng center,
    List<LatLng> points,
    double radiusMeters,
  ) {
    final result = <int>[];

    for (int i = 0; i < points.length; i++) {
      if (calculateDistance(center, points[i]) <= radiusMeters) {
        result.add(i);
      }
    }

    return result;
  }

  /// Calculate bounding box for a list of points
  ({LatLng southwest, LatLng northeast}) getBoundingBox(List<LatLng> points) {
    if (points.isEmpty) {
      return (
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return (
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Estimate duration from distance
  double estimateDuration(double distanceMeters, {String mode = 'driving'}) {
    // Average speeds (km/h)
    final speeds = {
      'driving': 25.0, // City driving
      'walking': 5.0,
      'bicycling': 15.0,
      'highway': 60.0,
    };

    final speedKmh = speeds[mode] ?? 25.0;
    return (distanceMeters / 1000 / speedKmh) * 3600; // Return seconds
  }

  /// Calculate bearing between two points
  double calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);

    final x = math.sin(dLon) * math.cos(lat2);
    final y = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    var bearing = math.atan2(x, y);
    bearing = _toDegrees(bearing);
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  /// Get point at distance and bearing from origin
  LatLng getPointAtDistance(
      LatLng origin, double distanceMeters, double bearingDegrees) {
    const R = 6371000.0; // Earth radius in meters
    final d = distanceMeters / R;
    final brng = _toRadians(bearingDegrees);
    final lat1 = _toRadians(origin.latitude);
    final lon1 = _toRadians(origin.longitude);

    final lat2 = math.asin(math.sin(lat1) * math.cos(d) +
        math.cos(lat1) * math.sin(d) * math.cos(brng));

    final lon2 = lon1 +
        math.atan2(math.sin(brng) * math.sin(d) * math.cos(lat1),
            math.cos(d) - math.sin(lat1) * math.sin(lat2));

    return LatLng(_toDegrees(lat2), _toDegrees(lon2));
  }

  /// Format distance for display
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  // ==================== PRIVATE HELPERS ====================

  double _haversine(LatLng p1, LatLng p2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLon = _toRadians(p2.longitude - p1.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(p1.latitude)) *
            math.cos(_toRadians(p2.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
  double _toDegrees(double radians) => radians * 180 / math.pi;
}
