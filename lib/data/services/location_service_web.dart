import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Web stub for location service
/// Returns default location since web doesn't support native GPS
class LocationService {
  // Default location (Bangalore, India)
  static const LatLng _defaultLocation = LatLng(12.9716, 77.5946);

  /// Request location permissions - always true on web
  Future<bool> requestPermission() async {
    debugPrint('LocationService (web): Permission stub - always true');
    return true;
  }

  /// Get current location - returns default on web
  Future<LatLng> getCurrentLocation() async {
    debugPrint('LocationService (web): Returning default location');
    return _defaultLocation;
  }

  /// Watch location changes - emits default on web
  Stream<LatLng> watchLocation() async* {
    debugPrint('LocationService (web): Watch location stub');
    yield _defaultLocation;
  }

  /// Get location stream - alias for watchLocation
  Stream<LatLng> getLocationStream() => watchLocation();

  /// Calculate distance between two points (in km)
  double distanceBetween(LatLng from, LatLng to) {
    final Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, from, to);
  }
}

// Provider for LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Provider for current location (async)
final currentLocationProvider = FutureProvider<LatLng>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getCurrentLocation();
});

// Provider for location stream (for live tracking)
final locationStreamProvider = StreamProvider<LatLng>((ref) {
  final service = ref.read(locationServiceProvider);
  return service.getLocationStream();
});
