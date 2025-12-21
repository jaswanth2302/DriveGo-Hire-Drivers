import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Real GPS location service with automatic detection
class LocationService {
  // Default location (Bangalore, India) - used as fallback
  static const LatLng _defaultLocation = LatLng(12.9716, 77.5946);

  /// Request location permissions
  Future<bool> requestPermission() async {
    if (kIsWeb) return true;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current GPS location automatically
  Future<LatLng> getCurrentLocation() async {
    // Web fallback - use default
    if (kIsWeb) {
      debugPrint('LocationService: Running on web, using default location');
      return _defaultLocation;
    }

    try {
      debugPrint('LocationService: Requesting permission...');
      // Request permission first
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint(
            'LocationService: Permission denied, using default location');
        return _defaultLocation;
      }
      debugPrint(
          'LocationService: Permission granted, getting GPS position...');

      // Get actual GPS position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      debugPrint(
          'LocationService: Got position: ${position.latitude}, ${position.longitude}');
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      // Return default on any error
      debugPrint('LocationService: Error getting location: $e');
      return _defaultLocation;
    }
  }

  /// Stream of location updates for live tracking
  Stream<LatLng> getLocationStream() {
    if (kIsWeb) {
      return Stream.value(_defaultLocation);
    }

    try {
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).map((position) => LatLng(position.latitude, position.longitude));
    } catch (e) {
      return Stream.value(_defaultLocation);
    }
  }

  /// Calculate distance between two points in kilometers
  double calculateDistance(LatLng from, LatLng to) {
    if (kIsWeb) {
      const Distance distance = Distance();
      return distance.as(LengthUnit.Kilometer, from, to);
    }

    try {
      return Geolocator.distanceBetween(
            from.latitude,
            from.longitude,
            to.latitude,
            to.longitude,
          ) /
          1000;
    } catch (e) {
      const Distance distance = Distance();
      return distance.as(LengthUnit.Kilometer, from, to);
    }
  }
}

/// Provider for LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Provider for current location (async) - auto-detects GPS on mobile
final currentLocationProvider = FutureProvider<LatLng>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getCurrentLocation();
});

/// Provider for location stream (for live tracking)
final locationStreamProvider = StreamProvider<LatLng>((ref) {
  final service = ref.read(locationServiceProvider);
  return service.getLocationStream();
});
