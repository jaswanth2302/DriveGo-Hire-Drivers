import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Ride Timing Mode
enum RideTimingMode {
  now, // Immediate matching
  tomorrow, // Tomorrow with time slot
  scheduled, // Future date & time
}

/// Ride State Machine
enum RideState {
  idle, // Initial state
  selectingDestination,
  selectingRide,
  confirming,
  scheduled, // For tomorrow/scheduled rides
  searching, // Finding driver (matching)
  driverAssigned, // Driver accepted
  driverEnRoute, // Driver coming to pickup
  driverArrived, // Driver at pickup
  tripInProgress, // Ride happening
  tripCompleted, // Ride done
  cancelled, // Ride cancelled
}

/// Ride Type Configuration
class RideType {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final double baseFare;
  final double perKm;
  final double perMin;
  final double minFare;
  final int etaMinutes;
  final int seats;

  const RideType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.baseFare,
    required this.perKm,
    required this.perMin,
    required this.minFare,
    required this.etaMinutes,
    required this.seats,
  });

  double calculateFare(double distanceKm, double durationMin) {
    final fare = baseFare + (perKm * distanceKm) + (perMin * durationMin);
    return fare < minFare ? minFare : fare;
  }

  static const List<RideType> all = [
    RideType(
      id: 'bike',
      name: 'Bike',
      description: 'Quick & affordable',
      icon: Icons.two_wheeler,
      baseFare: 20,
      perKm: 8,
      perMin: 1,
      minFare: 30,
      etaMinutes: 3,
      seats: 1,
    ),
    RideType(
      id: 'auto',
      name: 'Auto',
      description: 'Comfortable 3-wheeler',
      icon: Icons.electric_rickshaw,
      baseFare: 30,
      perKm: 12,
      perMin: 1.5,
      minFare: 40,
      etaMinutes: 5,
      seats: 3,
    ),
    RideType(
      id: 'mini',
      name: 'Mini',
      description: 'Budget cab',
      icon: Icons.directions_car,
      baseFare: 50,
      perKm: 14,
      perMin: 2,
      minFare: 70,
      etaMinutes: 7,
      seats: 4,
    ),
    RideType(
      id: 'sedan',
      name: 'Sedan',
      description: 'Comfortable sedan',
      icon: Icons.directions_car,
      baseFare: 80,
      perKm: 18,
      perMin: 2.5,
      minFare: 100,
      etaMinutes: 10,
      seats: 4,
    ),
    RideType(
      id: 'suv',
      name: 'SUV',
      description: 'Spacious ride',
      icon: Icons.directions_car_filled,
      baseFare: 120,
      perKm: 22,
      perMin: 3,
      minFare: 150,
      etaMinutes: 12,
      seats: 6,
    ),
  ];
}

/// Ride Location
class RideLocation {
  final String address;
  final String shortName;
  final double latitude;
  final double longitude;

  const RideLocation({
    required this.address,
    required this.shortName,
    required this.latitude,
    required this.longitude,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

/// Driver Info (no car details - they drive YOUR car)
class DriverInfo {
  final String id;
  final String name;
  final String photoUrl;
  final double rating;
  final int trips;
  final String phone;
  final LatLng? currentLocation;

  const DriverInfo({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.trips,
    required this.phone,
    this.currentLocation,
  });

  // Mock drivers
  static List<DriverInfo> mockDrivers = [
    DriverInfo(
      id: '1',
      name: 'Ramesh Kumar',
      photoUrl: '',
      rating: 4.8,
      trips: 1234,
      phone: '+91 98765 43210',
      currentLocation: const LatLng(12.9750, 77.5940),
    ),
    DriverInfo(
      id: '2',
      name: 'Suresh Reddy',
      photoUrl: '',
      rating: 4.6,
      trips: 856,
      phone: '+91 98765 43211',
      currentLocation: const LatLng(12.9720, 77.5980),
    ),
    DriverInfo(
      id: '3',
      name: 'Venkat Rao',
      photoUrl: '',
      rating: 4.9,
      trips: 2341,
      phone: '+91 98765 43212',
      currentLocation: const LatLng(12.9780, 77.5920),
    ),
    DriverInfo(
      id: '4',
      name: 'Arun Sharma',
      photoUrl: '',
      rating: 4.7,
      trips: 567,
      phone: '+91 98765 43213',
      currentLocation: const LatLng(12.9690, 77.6010),
    ),
  ];
}

/// Ride Booking (full state)
class RideBooking {
  final String id;
  final RideTimingMode timingMode;
  final DateTime? scheduledTime;
  final RideLocation pickup;
  final RideLocation drop;
  final RideType rideType;
  final double distanceKm;
  final double durationMin;
  final double fare;
  final String paymentMethod;
  final RideState state;
  final DriverInfo? driver;
  final double? driverDistanceMeters;
  final int? driverEtaMinutes;
  final String? otp;

  RideBooking({
    required this.id,
    required this.timingMode,
    this.scheduledTime,
    required this.pickup,
    required this.drop,
    required this.rideType,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.paymentMethod,
    required this.state,
    this.driver,
    this.driverDistanceMeters,
    this.driverEtaMinutes,
    this.otp,
  });

  RideBooking copyWith({
    RideState? state,
    DriverInfo? driver,
    double? driverDistanceMeters,
    int? driverEtaMinutes,
    String? otp,
  }) {
    return RideBooking(
      id: id,
      timingMode: timingMode,
      scheduledTime: scheduledTime,
      pickup: pickup,
      drop: drop,
      rideType: rideType,
      distanceKm: distanceKm,
      durationMin: durationMin,
      fare: fare,
      paymentMethod: paymentMethod,
      state: state ?? this.state,
      driver: driver ?? this.driver,
      driverDistanceMeters: driverDistanceMeters ?? this.driverDistanceMeters,
      driverEtaMinutes: driverEtaMinutes ?? this.driverEtaMinutes,
      otp: otp ?? this.otp,
    );
  }
}

/// Saved Place
class SavedPlace {
  final String name;
  final String address;
  final IconData icon;
  final double latitude;
  final double longitude;

  const SavedPlace({
    required this.name,
    required this.address,
    required this.icon,
    required this.latitude,
    required this.longitude,
  });
}

/// Recent Destination
class RecentDestination {
  final String address;
  final String shortName;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const RecentDestination({
    required this.address,
    required this.shortName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  static List<RecentDestination> mockRecents = [
    RecentDestination(
      address: 'Koramangala 4th Block, Bangalore',
      shortName: 'Koramangala',
      latitude: 12.9352,
      longitude: 77.6245,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    RecentDestination(
      address: 'Indiranagar Metro Station, Bangalore',
      shortName: 'Indiranagar Metro',
      latitude: 12.9784,
      longitude: 77.6408,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    RecentDestination(
      address: 'Whitefield, Bangalore',
      shortName: 'Whitefield',
      latitude: 12.9698,
      longitude: 77.7500,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
