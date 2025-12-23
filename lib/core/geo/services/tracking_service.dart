import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/geo_models.dart';

/// Tracking Service
///
/// Handles real-time driver location tracking, trail storage,
/// smooth animation, and deviation detection.
final trackingServiceProvider = Provider((ref) => TrackingService(ref));

class TrackingService {
  final Ref _ref;

  // Active tracking sessions
  final Map<String, _TrackingSession> _sessions = {};

  // Stream controllers for location updates
  final Map<String, StreamController<DriverLocationUpdate>> _locationStreams =
      {};

  TrackingService(this._ref);

  /// Start tracking a driver
  Stream<DriverLocationUpdate> startTracking(String driverId) {
    if (_locationStreams.containsKey(driverId)) {
      return _locationStreams[driverId]!.stream;
    }

    final controller = StreamController<DriverLocationUpdate>.broadcast();
    _locationStreams[driverId] = controller;
    _sessions[driverId] = _TrackingSession(driverId: driverId);

    print('[TrackingService] Started tracking driver: $driverId');
    return controller.stream;
  }

  /// Stop tracking a driver
  void stopTracking(String driverId) {
    _locationStreams[driverId]?.close();
    _locationStreams.remove(driverId);
    _sessions.remove(driverId);
    print('[TrackingService] Stopped tracking driver: $driverId');
  }

  /// Update driver location
  void updateLocation(DriverLocationUpdate update) {
    final session = _sessions[update.driverId];
    if (session == null) return;

    // Validate GPS accuracy (reject if > 100m accuracy)
    if (update.accuracy != null && update.accuracy! > 100) {
      print(
          '[TrackingService] Rejected low accuracy update: ${update.accuracy}m');
      return;
    }

    // Store in trail
    session.trail.add(TrailPoint(
      location: update.location,
      timestamp: update.timestamp,
      speed: update.speed,
    ));

    // Limit trail size (keep last 1000 points)
    if (session.trail.length > 1000) {
      session.trail.removeAt(0);
    }

    // Broadcast to listeners
    _locationStreams[update.driverId]?.add(update);
  }

  /// Get interpolated location (for smooth animation)
  LatLng getInterpolatedLocation(
    String driverId,
    LatLng from,
    LatLng to,
    double progress,
  ) {
    // Clamp progress to 0-1
    progress = progress.clamp(0.0, 1.0);

    // Linear interpolation
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * progress,
      from.longitude + (to.longitude - from.longitude) * progress,
    );
  }

  /// Get driver's current bearing (heading)
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

  /// Get location trail for a driver
  List<TrailPoint> getTrail(String driverId) {
    return _sessions[driverId]?.trail ?? [];
  }

  /// Get last known location
  LatLng? getLastKnownLocation(String driverId) {
    final trail = _sessions[driverId]?.trail;
    if (trail == null || trail.isEmpty) return null;
    return trail.last.location;
  }

  /// Check for route deviation
  Future<bool> isDeviated(
    String driverId,
    List<LatLng> plannedRoute,
    double thresholdMeters,
  ) async {
    final currentLocation = getLastKnownLocation(driverId);
    if (currentLocation == null) return false;

    // Find minimum distance to any point on planned route
    double minDistance = double.infinity;
    for (final point in plannedRoute) {
      final distance = _haversine(currentLocation, point);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance > thresholdMeters;
  }

  /// Compress trail for storage (reduce point count while preserving shape)
  List<TrailPoint> compressTrail(List<TrailPoint> trail, double tolerance) {
    if (trail.length < 3) return trail;

    // Douglas-Peucker simplification
    return _douglasPeucker(trail, tolerance);
  }

  /// Generate trail for replay
  List<TrailPoint> getReplayTrail(String driverId, {Duration? duration}) {
    final trail = _sessions[driverId]?.trail ?? [];
    if (duration == null) return trail;

    final cutoff = DateTime.now().subtract(duration);
    return trail.where((p) => p.timestamp.isAfter(cutoff)).toList();
  }

  // ==================== HELPERS ====================

  double _haversine(LatLng p1, LatLng p2) {
    const R = 6371000.0;
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

  double _toRadians(double deg) => deg * math.pi / 180;
  double _toDegrees(double rad) => rad * 180 / math.pi;

  List<TrailPoint> _douglasPeucker(List<TrailPoint> points, double epsilon) {
    if (points.length < 3) return points;

    double maxDist = 0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = _perpendicularDistance(
        points[i].location,
        points.first.location,
        points.last.location,
      );
      if (dist > maxDist) {
        maxDist = dist;
        index = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _douglasPeucker(points.sublist(0, index + 1), epsilon);
      final right = _douglasPeucker(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }

    return [points.first, points.last];
  }

  double _perpendicularDistance(
      LatLng point, LatLng lineStart, LatLng lineEnd) {
    // Simplified perpendicular distance
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    final norm = math.sqrt(dx * dx + dy * dy);
    if (norm == 0) return _haversine(point, lineStart);

    final dist = ((point.longitude - lineStart.longitude) * dy -
                (point.latitude - lineStart.latitude) * dx)
            .abs() /
        norm;

    return dist * 111000; // Approximate meters
  }

  void dispose() {
    for (final controller in _locationStreams.values) {
      controller.close();
    }
    _locationStreams.clear();
    _sessions.clear();
  }
}

class _TrackingSession {
  final String driverId;
  final List<TrailPoint> trail = [];
  final DateTime startedAt = DateTime.now();
  LatLng? lastLocation;
  DateTime? lastUpdate;

  _TrackingSession({required this.driverId});
}
