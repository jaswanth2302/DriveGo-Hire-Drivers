import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/geo_models.dart';

/// Safety Service
///
/// Handles deviation detection, SOS, speed monitoring, and safety alerts.
/// Provides audit trail for disputes and compliance.
final safetyServiceProvider = Provider((ref) => SafetyService(ref));

class SafetyService {
  final Ref _ref;

  final StreamController<SafetyAlert> _alertController =
      StreamController.broadcast();
  final List<SafetyAlert> _alertHistory = [];

  // Thresholds
  static const double deviationThresholdMeters = 500; // 500m
  static const double speedThresholdKmh = 100; // 100 km/h
  static const Duration idleThreshold = Duration(minutes: 5);

  SafetyService(this._ref);

  /// Stream of safety alerts
  Stream<SafetyAlert> get alerts => _alertController.stream;

  /// Get alert history
  List<SafetyAlert> get history => List.unmodifiable(_alertHistory);

  /// Check for route deviation
  Future<SafetyAlert?> checkDeviation(
    String tripId,
    LatLng currentLocation,
    List<LatLng> plannedRoute,
  ) async {
    // Find minimum distance to planned route
    double minDist = double.infinity;
    for (final point in plannedRoute) {
      final dist = _distance(currentLocation, point);
      if (dist < minDist) minDist = dist;
    }

    if (minDist > deviationThresholdMeters) {
      final alert = SafetyAlert(
        alertId: 'dev_${DateTime.now().millisecondsSinceEpoch}',
        type: 'deviation',
        message:
            'Vehicle deviated ${(minDist / 1000).toStringAsFixed(1)}km from route',
        location: currentLocation,
        timestamp: DateTime.now(),
        metadata: {
          'tripId': tripId,
          'deviationMeters': minDist,
        },
      );

      _addAlert(alert);
      return alert;
    }

    return null;
  }

  /// Check for excessive speed
  SafetyAlert? checkSpeed(
    String tripId,
    LatLng location,
    double speedKmh,
  ) {
    if (speedKmh > speedThresholdKmh) {
      final alert = SafetyAlert(
        alertId: 'spd_${DateTime.now().millisecondsSinceEpoch}',
        type: 'speed',
        message: 'Excessive speed: ${speedKmh.toInt()} km/h',
        location: location,
        timestamp: DateTime.now(),
        metadata: {
          'tripId': tripId,
          'speedKmh': speedKmh,
        },
      );

      _addAlert(alert);
      return alert;
    }

    return null;
  }

  /// Trigger SOS alert
  SafetyAlert triggerSOS({
    required String tripId,
    required String userId,
    required LatLng location,
    String? message,
  }) {
    final alert = SafetyAlert(
      alertId: 'sos_${DateTime.now().millisecondsSinceEpoch}',
      type: 'sos',
      message: message ?? 'SOS triggered by user',
      location: location,
      timestamp: DateTime.now(),
      metadata: {
        'tripId': tripId,
        'userId': userId,
        'priority': 'critical',
      },
    );

    _addAlert(alert);

    // TODO: Send to backend, notify emergency contacts
    print('[SafetyService] ⚠️ SOS ALERT: $alert');

    return alert;
  }

  /// Check for idle state (potential issue)
  SafetyAlert? checkIdle(
    String tripId,
    LatLng location,
    DateTime lastMovement,
  ) {
    if (DateTime.now().difference(lastMovement) > idleThreshold) {
      final alert = SafetyAlert(
        alertId: 'idle_${DateTime.now().millisecondsSinceEpoch}',
        type: 'idle',
        message: 'Vehicle has been stationary for extended period',
        location: location,
        timestamp: DateTime.now(),
        metadata: {
          'tripId': tripId,
          'idleMinutes': DateTime.now().difference(lastMovement).inMinutes,
        },
      );

      _addAlert(alert);
      return alert;
    }

    return null;
  }

  /// Get alerts for a trip
  List<SafetyAlert> getAlertsForTrip(String tripId) {
    return _alertHistory.where((a) => a.metadata?['tripId'] == tripId).toList();
  }

  /// Clear alerts for a trip
  void clearAlertsForTrip(String tripId) {
    _alertHistory.removeWhere((a) => a.metadata?['tripId'] == tripId);
  }

  /// Generate safety report for trip
  Map<String, dynamic> generateSafetyReport(String tripId) {
    final tripAlerts = getAlertsForTrip(tripId);

    return {
      'tripId': tripId,
      'generatedAt': DateTime.now().toIso8601String(),
      'totalAlerts': tripAlerts.length,
      'alertsByType': {
        'deviation': tripAlerts.where((a) => a.type == 'deviation').length,
        'speed': tripAlerts.where((a) => a.type == 'speed').length,
        'sos': tripAlerts.where((a) => a.type == 'sos').length,
        'idle': tripAlerts.where((a) => a.type == 'idle').length,
      },
      'alerts': tripAlerts
          .map((a) => {
                'id': a.alertId,
                'type': a.type,
                'message': a.message,
                'timestamp': a.timestamp.toIso8601String(),
                'location': {
                  'lat': a.location.latitude,
                  'lng': a.location.longitude,
                },
              })
          .toList(),
    };
  }

  void _addAlert(SafetyAlert alert) {
    _alertHistory.add(alert);
    _alertController.add(alert);

    // Keep only last 1000 alerts
    if (_alertHistory.length > 1000) {
      _alertHistory.removeAt(0);
    }
  }

  double _distance(LatLng p1, LatLng p2) {
    const R = 6371000.0;
    final dLat = (p2.latitude - p1.latitude) * 3.14159 / 180;
    final dLon = (p2.longitude - p1.longitude) * 3.14159 / 180;
    final a = 0.5 -
        (dLat / 2).abs() / 2 +
        (p1.latitude * 3.14159 / 180).abs() *
            (p2.latitude * 3.14159 / 180).abs() *
            (1 - (dLon / 2).abs()) /
            2;
    return R *
        2 *
        (a < 0
            ? 0
            : a > 1
                ? 1
                : a);
  }

  void dispose() {
    _alertController.close();
  }
}
