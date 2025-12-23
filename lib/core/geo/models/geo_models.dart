import 'package:latlong2/latlong.dart';

/// Geographic Address
class GeoAddress {
  final String placeId;
  final String formattedAddress;
  final String shortName;
  final LatLng location;
  final String? streetNumber;
  final String? street;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  const GeoAddress({
    required this.placeId,
    required this.formattedAddress,
    required this.shortName,
    required this.location,
    this.streetNumber,
    this.street,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'formattedAddress': formattedAddress,
        'shortName': shortName,
        'lat': location.latitude,
        'lng': location.longitude,
        'city': city,
        'state': state,
      };
}

/// Place Suggestion (Autocomplete)
class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;
  final LatLng? location; // May be null until geocoded

  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
    this.location,
  });
}

/// Route Result
class RouteResult {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;
  final String? polylineEncoded;
  final List<RouteStep>? steps;

  const RouteResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    this.polylineEncoded,
    this.steps,
  });

  double get distanceKm => distanceMeters / 1000;
  double get durationMinutes => durationSeconds / 60;

  String get formattedDistance {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    if (durationSeconds < 60) return '${durationSeconds.round()} sec';
    if (durationSeconds < 3600) return '${durationMinutes.round()} min';
    final hours = (durationSeconds / 3600).floor();
    final mins = ((durationSeconds % 3600) / 60).round();
    return '$hours hr $mins min';
  }
}

/// Route Step (Turn-by-turn)
class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;
  final String? maneuver;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
    this.maneuver,
  });
}

/// Distance Matrix Entry
class DistanceMatrixEntry {
  final LatLng origin;
  final LatLng destination;
  final double distanceMeters;
  final double durationSeconds;
  final bool isValid;

  const DistanceMatrixEntry({
    required this.origin,
    required this.destination,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isValid = true,
  });
}

/// Distance Matrix Result
class DistanceMatrix {
  final List<LatLng> origins;
  final List<LatLng> destinations;
  final List<List<DistanceMatrixEntry>> rows;

  const DistanceMatrix({
    required this.origins,
    required this.destinations,
    required this.rows,
  });

  DistanceMatrixEntry? getEntry(int originIndex, int destinationIndex) {
    if (originIndex < rows.length &&
        destinationIndex < rows[originIndex].length) {
      return rows[originIndex][destinationIndex];
    }
    return null;
  }
}

/// Driver Location Update
class DriverLocationUpdate {
  final String driverId;
  final LatLng location;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime timestamp;

  const DriverLocationUpdate({
    required this.driverId,
    required this.location,
    this.heading,
    this.speed,
    this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        'lat': location.latitude,
        'lng': location.longitude,
        'heading': heading,
        'speed': speed,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Location Trail Point (for replay)
class TrailPoint {
  final LatLng location;
  final DateTime timestamp;
  final double? speed;

  const TrailPoint({
    required this.location,
    required this.timestamp,
    this.speed,
  });
}

/// ETA Result with adjustments
class ETAResult {
  final double baseSeconds;
  final double adjustedSeconds;
  final double multiplier;
  final String reason;
  final DateTime calculatedAt;

  const ETAResult({
    required this.baseSeconds,
    required this.adjustedSeconds,
    required this.multiplier,
    required this.reason,
    required this.calculatedAt,
  });

  String get formattedETA {
    final mins = (adjustedSeconds / 60).round();
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    return '$hours hr $remainingMins min';
  }
}

/// Geofence Event
enum GeofenceEventType {
  entered,
  exited,
  dwell,
}

class GeofenceEvent {
  final String geofenceId;
  final GeofenceEventType type;
  final LatLng location;
  final DateTime timestamp;

  const GeofenceEvent({
    required this.geofenceId,
    required this.type,
    required this.location,
    required this.timestamp,
  });
}

/// Trip State (comprehensive)
enum TripState {
  idle,
  searching,
  driverAssigned,
  driverEnRouteToPickup,
  driverArrivedAtPickup,
  tripInProgress,
  waiting,
  returnJourney,
  completed,
  cancelled,
}

/// Safety Alert
class SafetyAlert {
  final String alertId;
  final String type; // 'deviation', 'speed', 'sos', 'idle'
  final String message;
  final LatLng location;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const SafetyAlert({
    required this.alertId,
    required this.type,
    required this.message,
    required this.location,
    required this.timestamp,
    this.metadata,
  });
}
