import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../models/geo_models.dart';
import 'map_provider.dart';

/// Mock Map Provider
///
/// Returns deterministic fake data for development/testing.
/// All calls are logged for debugging.
class MockMapProvider implements MapProvider {
  @override
  String get providerName => 'Mock';

  final _random = math.Random(42); // Seeded for deterministic results

  // Mock location database
  static const _mockLocations = [
    {
      'name': 'Koramangala',
      'address': 'Koramangala 4th Block, Bangalore',
      'lat': 12.9352,
      'lng': 77.6245
    },
    {
      'name': 'Indiranagar',
      'address': 'Indiranagar, Bangalore',
      'lat': 12.9784,
      'lng': 77.6408
    },
    {
      'name': 'Whitefield',
      'address': 'Whitefield, Bangalore',
      'lat': 12.9698,
      'lng': 77.7500
    },
    {
      'name': 'MG Road',
      'address': 'MG Road, Bangalore',
      'lat': 12.9756,
      'lng': 77.6066
    },
    {
      'name': 'Electronic City',
      'address': 'Electronic City, Bangalore',
      'lat': 12.8399,
      'lng': 77.6770
    },
    {
      'name': 'HSR Layout',
      'address': 'HSR Layout, Bangalore',
      'lat': 12.9116,
      'lng': 77.6446
    },
    {
      'name': 'Marathahalli',
      'address': 'Marathahalli, Bangalore',
      'lat': 12.9591,
      'lng': 77.6972
    },
    {
      'name': 'Jayanagar',
      'address': 'Jayanagar, Bangalore',
      'lat': 12.9304,
      'lng': 77.5838
    },
    {
      'name': 'BTM Layout',
      'address': 'BTM Layout, Bangalore',
      'lat': 12.9166,
      'lng': 77.6101
    },
    {
      'name': 'Hebbal',
      'address': 'Hebbal, Bangalore',
      'lat': 13.0358,
      'lng': 77.5970
    },
    {
      'name': 'Airport',
      'address': 'Kempegowda International Airport',
      'lat': 13.1989,
      'lng': 77.7068
    },
    {
      'name': 'Majestic',
      'address': 'Majestic Bus Stand, Bangalore',
      'lat': 12.9767,
      'lng': 77.5713
    },
  ];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<PlaceSuggestion>> getAutocompleteSuggestions(
    String query, {
    LatLng? nearLocation,
    int maxResults = 5,
  }) async {
    _log('getAutocompleteSuggestions: "$query"');

    await Future.delayed(const Duration(milliseconds: 100)); // Simulate network

    final results = _mockLocations
        .where((loc) =>
            loc['name']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            loc['address']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
        .take(maxResults)
        .map((loc) => PlaceSuggestion(
              placeId:
                  'mock_${loc['name'].toString().toLowerCase().replaceAll(' ', '_')}',
              mainText: loc['name'] as String,
              secondaryText: loc['address'] as String,
              fullText: loc['address'] as String,
              location: LatLng(loc['lat'] as double, loc['lng'] as double),
            ))
        .toList();

    return results;
  }

  @override
  Future<GeoAddress?> geocodeAddress(String address) async {
    _log('geocodeAddress: "$address"');

    await Future.delayed(const Duration(milliseconds: 50));

    final match = _mockLocations.firstWhere(
      (loc) => loc['address']
          .toString()
          .toLowerCase()
          .contains(address.toLowerCase()),
      orElse: () => _mockLocations.first,
    );

    return GeoAddress(
      placeId: 'mock_geocode',
      formattedAddress: match['address'] as String,
      shortName: match['name'] as String,
      location: LatLng(match['lat'] as double, match['lng'] as double),
      city: 'Bangalore',
      state: 'Karnataka',
      country: 'India',
    );
  }

  @override
  Future<GeoAddress?> reverseGeocode(LatLng location) async {
    _log('reverseGeocode: ${location.latitude}, ${location.longitude}');

    await Future.delayed(const Duration(milliseconds: 50));

    // Find nearest mock location
    var nearest = _mockLocations.first;
    var nearestDist = double.infinity;

    for (final loc in _mockLocations) {
      final dist = _haversine(
        location,
        LatLng(loc['lat'] as double, loc['lng'] as double),
      );
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = loc;
      }
    }

    return GeoAddress(
      placeId: 'mock_reverse',
      formattedAddress: nearest['address'] as String,
      shortName: nearest['name'] as String,
      location: location,
      city: 'Bangalore',
      state: 'Karnataka',
      country: 'India',
    );
  }

  @override
  Future<RouteResult?> calculateRoute(
    LatLng origin,
    LatLng destination, {
    List<LatLng>? waypoints,
    String mode = 'driving',
  }) async {
    _log(
        'calculateRoute: ${origin.latitude},${origin.longitude} -> ${destination.latitude},${destination.longitude}');

    await Future.delayed(const Duration(milliseconds: 100));

    // Calculate distance using Haversine
    final distanceMeters = _haversine(origin, destination);

    // Generate mock polyline (curved path)
    final points = _generateMockPolyline(origin, destination);

    // Calculate duration based on mode
    final speedKmh = mode == 'walking'
        ? 5.0
        : mode == 'bicycling'
            ? 15.0
            : 25.0;
    final durationSeconds = (distanceMeters / 1000 / speedKmh) * 3600;

    return RouteResult(
      polylinePoints: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<DistanceMatrix?> calculateDistanceMatrix(
    List<LatLng> origins,
    List<LatLng> destinations, {
    String mode = 'driving',
  }) async {
    _log(
        'calculateDistanceMatrix: ${origins.length} origins x ${destinations.length} destinations');

    await Future.delayed(const Duration(milliseconds: 150));

    final rows = <List<DistanceMatrixEntry>>[];

    for (final origin in origins) {
      final row = <DistanceMatrixEntry>[];
      for (final dest in destinations) {
        final distance = _haversine(origin, dest);
        final duration = (distance / 1000 / 25.0) * 3600; // 25 km/h average

        row.add(DistanceMatrixEntry(
          origin: origin,
          destination: dest,
          distanceMeters: distance,
          durationSeconds: duration,
        ));
      }
      rows.add(row);
    }

    return DistanceMatrix(
      origins: origins,
      destinations: destinations,
      rows: rows,
    );
  }

  @override
  Future<List<LatLng>> snapToRoads(List<LatLng> points) async {
    _log('snapToRoads: ${points.length} points');
    // Mock: return same points with slight adjustments
    return points
        .map((p) => LatLng(
              p.latitude + (_random.nextDouble() - 0.5) * 0.0001,
              p.longitude + (_random.nextDouble() - 0.5) * 0.0001,
            ))
        .toList();
  }

  @override
  Future<List<PlaceSuggestion>> getNearbyPlaces(
    LatLng location,
    String type, {
    double radiusMeters = 1000,
  }) async {
    _log('getNearbyPlaces: $type within ${radiusMeters}m');

    return _mockLocations
        .where((loc) =>
            _haversine(
                location, LatLng(loc['lat'] as double, loc['lng'] as double)) <=
            radiusMeters)
        .map((loc) => PlaceSuggestion(
              placeId: 'mock_nearby',
              mainText: loc['name'] as String,
              secondaryText: loc['address'] as String,
              fullText: loc['address'] as String,
              location: LatLng(loc['lat'] as double, loc['lng'] as double),
            ))
        .toList();
  }

  // ==================== HELPERS ====================

  /// Haversine distance calculation
  double _haversine(LatLng p1, LatLng p2) {
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

  /// Generate mock polyline with some curvature
  List<LatLng> _generateMockPolyline(LatLng start, LatLng end) {
    final points = <LatLng>[];
    const segments = 20;

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;

      // Linear interpolation with slight curve
      final lat = start.latitude + (end.latitude - start.latitude) * t;
      final lng = start.longitude + (end.longitude - start.longitude) * t;

      // Add slight curve
      final curveOffset = math.sin(t * math.pi) * 0.002;

      points.add(LatLng(lat + curveOffset, lng));
    }

    return points;
  }

  void _log(String message) {
    print('[MockMapProvider] $message');
  }
}
