import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// Service
class MockLocationService {
  // Bangalore Coordinates
  final LatLng _initialLocation = const LatLng(12.9716, 77.5946);

  Stream<LatLng> getLocationStream() {
    return Stream.periodic(const Duration(seconds: 3), (i) {
      // Simulate slight movement
      return LatLng(_initialLocation.latitude + (i * 0.0001),
          _initialLocation.longitude + (i * 0.0001));
    });
  }

  Future<LatLng> getCurrentLocation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _initialLocation;
  }
}

// Provider
final locationServiceProvider = Provider<MockLocationService>((ref) {
  return MockLocationService();
});

final currentLocationProvider = FutureProvider<LatLng>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.getCurrentLocation();
});
