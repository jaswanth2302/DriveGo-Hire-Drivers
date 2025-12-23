import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/geo_models.dart';
import '../models/zone_models.dart';

/// Geofence Service
///
/// Handles zone detection, arrival triggers, and boundary events.
/// Used for driver arrival, pickup/drop detection, and zone-based pricing.
final geofenceServiceProvider = Provider((ref) => GeofenceService());

class GeofenceService {
  final List<CircularGeofence> _activeGeofences = [];
  final Map<String, bool> _insideStatus = {};
  final StreamController<GeofenceEvent> _eventController =
      StreamController.broadcast();

  /// Stream of geofence events
  Stream<GeofenceEvent> get events => _eventController.stream;

  /// Add a geofence to monitor
  void addGeofence(CircularGeofence geofence) {
    _activeGeofences.add(geofence);
    _insideStatus[geofence.id] = false;
    print('[GeofenceService] Added geofence: ${geofence.name}');
  }

  /// Remove a geofence
  void removeGeofence(String id) {
    _activeGeofences.removeWhere((g) => g.id == id);
    _insideStatus.remove(id);
    print('[GeofenceService] Removed geofence: $id');
  }

  /// Clear all geofences
  void clearAll() {
    _activeGeofences.clear();
    _insideStatus.clear();
  }

  /// Check location against all geofences
  List<GeofenceEvent> checkLocation(LatLng location) {
    final events = <GeofenceEvent>[];

    for (final geofence in _activeGeofences) {
      final isInside = geofence.containsPoint(location);
      final wasInside = _insideStatus[geofence.id] ?? false;

      if (isInside && !wasInside) {
        // Entered geofence
        final event = GeofenceEvent(
          geofenceId: geofence.id,
          type: GeofenceEventType.entered,
          location: location,
          timestamp: DateTime.now(),
        );
        events.add(event);
        _eventController.add(event);
        print('[GeofenceService] ENTERED: ${geofence.name}');
      } else if (!isInside && wasInside) {
        // Exited geofence
        final event = GeofenceEvent(
          geofenceId: geofence.id,
          type: GeofenceEventType.exited,
          location: location,
          timestamp: DateTime.now(),
        );
        events.add(event);
        _eventController.add(event);
        print('[GeofenceService] EXITED: ${geofence.name}');
      }

      _insideStatus[geofence.id] = isInside;
    }

    return events;
  }

  /// Create pickup geofence
  CircularGeofence createPickupGeofence(String bookingId, LatLng pickup) {
    return CircularGeofence(
      id: 'pickup_$bookingId',
      name: 'Pickup Location',
      center: pickup,
      radiusMeters: 100, // 100m radius
      triggeredBy: 'driver',
    );
  }

  /// Create drop geofence
  CircularGeofence createDropGeofence(String bookingId, LatLng drop) {
    return CircularGeofence(
      id: 'drop_$bookingId',
      name: 'Drop Location',
      center: drop,
      radiusMeters: 100,
      triggeredBy: 'driver',
    );
  }

  /// Check if driver has arrived at pickup
  bool isDriverAtPickup(String bookingId) {
    return _insideStatus['pickup_$bookingId'] ?? false;
  }

  /// Check if driver has arrived at drop
  bool isDriverAtDrop(String bookingId) {
    return _insideStatus['drop_$bookingId'] ?? false;
  }

  /// Get zone for location
  GeoZone? getZoneForLocation(LatLng location, List<GeoZone> zones) {
    for (final zone in zones) {
      if (zone.containsPoint(location)) {
        return zone;
      }
    }
    return null;
  }

  /// Check if location is within service area
  bool isInServiceArea(LatLng location) {
    return BangaloreZones.cityBoundary.containsPoint(location);
  }

  /// Get all zones containing a location
  List<GeoZone> getZonesForLocation(LatLng location) {
    return BangaloreZones.allZones
        .where((z) => z.containsPoint(location))
        .toList();
  }

  void dispose() {
    _eventController.close();
  }
}
