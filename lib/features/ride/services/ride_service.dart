import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/ride_models.dart';

/// Ride Service - Handles ride booking logic
class RideService {
  static final RideService _instance = RideService._();
  factory RideService() => _instance;
  RideService._();

  final _random = Random();

  /// Calculate distance between two points (Haversine formula)
  double calculateDistance(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, from, to);
  }

  /// Estimate trip duration based on distance and average speed
  double estimateDuration(double distanceKm, String rideType) {
    // Average speeds (km/h) by ride type
    final speeds = {
      'bike': 25.0,
      'auto': 20.0,
      'mini': 30.0,
      'sedan': 35.0,
      'suv': 30.0,
    };

    final speed = speeds[rideType] ?? 25.0;
    // Duration in minutes + traffic buffer
    return (distanceKm / speed) * 60 * 1.3; // 30% traffic buffer
  }

  /// Get fare for a ride type
  double calculateFare(
      RideType rideType, double distanceKm, double durationMin) {
    return rideType.calculateFare(distanceKm, durationMin);
  }

  /// Find nearby drivers (mock)
  Future<List<DriverInfo>> findNearbyDrivers(
      LatLng location, String rideType) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(500)));

    // Return mock drivers
    return DriverInfo.mockDrivers;
  }

  /// Request a ride (mock)
  Future<DriverInfo?> requestRide(RideBooking request) async {
    // Simulate matching delay (2-5 seconds)
    await Future.delayed(Duration(seconds: 2 + _random.nextInt(3)));

    // 90% success rate
    if (_random.nextDouble() < 0.9) {
      return DriverInfo
          .mockDrivers[_random.nextInt(DriverInfo.mockDrivers.length)];
    }

    return null;
  }

  /// Get driver ETA to pickup (mock)
  int getDriverEta(String driverId, LatLng pickup) {
    // Mock: 2-10 minutes
    return 2 + _random.nextInt(8);
  }

  /// Cancel ride
  Future<bool> cancelRide(String rideId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  /// Complete ride
  Future<bool> completeRide(String rideId, double actualFare) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  /// Rate driver
  Future<bool> rateDriver(String driverId, int rating, String? feedback) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  /// Generate mock driver locations around a point
  List<LatLng> generateNearbyDriverLocations(LatLng center, int count) {
    final locations = <LatLng>[];
    for (int i = 0; i < count; i++) {
      // Random offset within ~2km
      final latOffset = (_random.nextDouble() - 0.5) * 0.04;
      final lngOffset = (_random.nextDouble() - 0.5) * 0.04;
      locations.add(LatLng(
        center.latitude + latOffset,
        center.longitude + lngOffset,
      ));
    }
    return locations;
  }
}
