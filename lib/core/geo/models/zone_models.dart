import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// Zone Type
enum ZoneType {
  city, // City boundary
  service, // Service area
  surge, // Surge pricing zone
  restricted, // No service
  airport, // Special airport zone
  hub, // Driver hub
}

/// Zone (Polygon-based)
class GeoZone {
  final String id;
  final String name;
  final ZoneType type;
  final List<LatLng> polygon;
  final Map<String, dynamic>? metadata;
  final bool isActive;

  const GeoZone({
    required this.id,
    required this.name,
    required this.type,
    required this.polygon,
    this.metadata,
    this.isActive = true,
  });

  /// Check if a point is inside this zone (Ray casting algorithm)
  bool containsPoint(LatLng point) {
    if (polygon.length < 3) return false;

    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      if (((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude <
              (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)) {
        intersections++;
      }
    }

    return intersections.isOdd;
  }

  /// Get center of zone
  LatLng get center {
    double latSum = 0, lngSum = 0;
    for (final p in polygon) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / polygon.length, lngSum / polygon.length);
  }
}

/// Circular Geofence
class CircularGeofence {
  final String id;
  final String name;
  final LatLng center;
  final double radiusMeters;
  final String? triggeredBy; // 'driver', 'user', 'both'

  const CircularGeofence({
    required this.id,
    required this.name,
    required this.center,
    required this.radiusMeters,
    this.triggeredBy = 'both',
  });

  /// Check if point is inside geofence
  bool containsPoint(LatLng point) {
    return _haversineDistance(center, point) <= radiusMeters;
  }

  /// Haversine distance calculation
  double _haversineDistance(LatLng p1, LatLng p2) {
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
}

/// City Configuration
class CityConfig {
  final String id;
  final String name;
  final GeoZone boundary;
  final List<GeoZone> serviceZones;
  final Map<String, double> pricingMultipliers;
  final double defaultSpeedKmh;
  final bool isActive;

  const CityConfig({
    required this.id,
    required this.name,
    required this.boundary,
    required this.serviceZones,
    required this.pricingMultipliers,
    this.defaultSpeedKmh = 25.0,
    this.isActive = true,
  });

  /// Check if a point is within this city
  bool containsPoint(LatLng point) => boundary.containsPoint(point);

  /// Get pricing multiplier for a zone type
  double getPricingMultiplier(String zoneId) {
    return pricingMultipliers[zoneId] ?? 1.0;
  }
}

/// Pre-configured zones for Bangalore
class BangaloreZones {
  static final cityBoundary = GeoZone(
    id: 'blr_city',
    name: 'Bangalore',
    type: ZoneType.city,
    polygon: [
      const LatLng(13.1500, 77.4000), // NW
      const LatLng(13.1500, 77.8000), // NE
      const LatLng(12.7500, 77.8000), // SE
      const LatLng(12.7500, 77.4000), // SW
    ],
  );

  static final koramangala = GeoZone(
    id: 'blr_koramangala',
    name: 'Koramangala',
    type: ZoneType.service,
    polygon: [
      const LatLng(12.9450, 77.6100),
      const LatLng(12.9450, 77.6400),
      const LatLng(12.9200, 77.6400),
      const LatLng(12.9200, 77.6100),
    ],
  );

  static final indiranagar = GeoZone(
    id: 'blr_indiranagar',
    name: 'Indiranagar',
    type: ZoneType.service,
    polygon: [
      const LatLng(12.9850, 77.6300),
      const LatLng(12.9850, 77.6550),
      const LatLng(12.9650, 77.6550),
      const LatLng(12.9650, 77.6300),
    ],
  );

  static final airport = GeoZone(
    id: 'blr_airport',
    name: 'Kempegowda Airport',
    type: ZoneType.airport,
    polygon: [
      const LatLng(13.2100, 77.6900),
      const LatLng(13.2100, 77.7200),
      const LatLng(13.1800, 77.7200),
      const LatLng(13.1800, 77.6900),
    ],
    metadata: {'surgeMultiplier': 1.5},
  );

  static List<GeoZone> get allZones => [
        cityBoundary,
        koramangala,
        indiranagar,
        airport,
      ];
}
