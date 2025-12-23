import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/geo_models.dart';
import 'map_provider.dart';

/// OSRM Map Provider
///
/// Uses Open Source Routing Machine for real route calculation.
/// Free, no API key required.
///
/// Demo server: https://router.project-osrm.org
/// For production, host your own OSRM instance.
class OSRMMapProvider implements MapProvider {
  final String baseUrl;

  OSRMMapProvider({this.baseUrl = 'https://router.project-osrm.org'});

  @override
  String get providerName => 'OSRM';

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(
            const Duration(seconds: 5),
          );
      return response.statusCode == 200;
    } catch (e) {
      // OSRM demo server doesn't have /health, so check route endpoint
      return true; // Assume available
    }
  }

  @override
  Future<List<PlaceSuggestion>> getAutocompleteSuggestions(
    String query, {
    LatLng? nearLocation,
    int maxResults = 5,
  }) async {
    // OSRM doesn't support autocomplete - use Nominatim or mock
    _log(
        'getAutocompleteSuggestions: OSRM does not support this, returning empty');
    return [];
  }

  @override
  Future<GeoAddress?> geocodeAddress(String address) async {
    // Use Nominatim for geocoding (free)
    try {
      final url = 'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(address)}'
          '&format=json&limit=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Drivo/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final result = data.first;
          return GeoAddress(
            placeId: result['place_id'].toString(),
            formattedAddress: result['display_name'] ?? address,
            shortName: result['name'] ?? address.split(',').first,
            location: LatLng(
              double.parse(result['lat']),
              double.parse(result['lon']),
            ),
          );
        }
      }
    } catch (e) {
      _log('geocodeAddress error: $e');
    }
    return null;
  }

  @override
  Future<GeoAddress?> reverseGeocode(LatLng location) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse'
          '?lat=${location.latitude}&lon=${location.longitude}'
          '&format=json';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Drivo/1.0'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final address = result['address'] ?? {};

        return GeoAddress(
          placeId: result['place_id']?.toString() ?? '',
          formattedAddress: result['display_name'] ?? '',
          shortName: address['suburb'] ??
              address['neighbourhood'] ??
              address['road'] ??
              '',
          location: location,
          street: address['road'],
          city: address['city'] ?? address['town'] ?? address['village'],
          state: address['state'],
          postalCode: address['postcode'],
          country: address['country'],
        );
      }
    } catch (e) {
      _log('reverseGeocode error: $e');
    }
    return null;
  }

  @override
  Future<RouteResult?> calculateRoute(
    LatLng origin,
    LatLng destination, {
    List<LatLng>? waypoints,
    String mode = 'driving',
  }) async {
    try {
      // Build coordinates string
      var coords = '${origin.longitude},${origin.latitude}';
      if (waypoints != null) {
        for (final wp in waypoints) {
          coords += ';${wp.longitude},${wp.latitude}';
        }
      }
      coords += ';${destination.longitude},${destination.latitude}';

      // Map mode to OSRM profile
      final profile = mode == 'walking'
          ? 'foot'
          : mode == 'bicycling'
              ? 'bike'
              : 'driving';

      final url = '$baseUrl/route/v1/$profile/$coords'
          '?overview=full&geometries=polyline&steps=true';

      _log('calculateRoute: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Decode polyline
          final polylinePoints = _decodePolyline(route['geometry']);

          // Extract steps if available
          List<RouteStep>? steps;
          if (route['legs'] != null) {
            steps = [];
            for (final leg in route['legs']) {
              if (leg['steps'] != null) {
                for (final step in leg['steps']) {
                  steps.add(RouteStep(
                    instruction: step['name'] ?? '',
                    distanceMeters: (step['distance'] as num).toDouble(),
                    durationSeconds: (step['duration'] as num).toDouble(),
                    startLocation: LatLng(
                      step['maneuver']['location'][1],
                      step['maneuver']['location'][0],
                    ),
                    endLocation: LatLng(
                      step['maneuver']['location'][1],
                      step['maneuver']['location'][0],
                    ),
                    maneuver: step['maneuver']['type'],
                  ));
                }
              }
            }
          }

          return RouteResult(
            polylinePoints: polylinePoints,
            distanceMeters: (route['distance'] as num).toDouble(),
            durationSeconds: (route['duration'] as num).toDouble(),
            polylineEncoded: route['geometry'],
            steps: steps,
          );
        }
      }
    } catch (e) {
      _log('calculateRoute error: $e');
    }
    return null;
  }

  @override
  Future<DistanceMatrix?> calculateDistanceMatrix(
    List<LatLng> origins,
    List<LatLng> destinations, {
    String mode = 'driving',
  }) async {
    try {
      // Build all coordinates
      final allCoords = [...origins, ...destinations];
      final coordsStr =
          allCoords.map((c) => '${c.longitude},${c.latitude}').join(';');

      // Build source indices
      final sourceIndices = List.generate(origins.length, (i) => i).join(';');
      final destIndices =
          List.generate(destinations.length, (i) => origins.length + i)
              .join(';');

      final profile = mode == 'walking' ? 'foot' : 'driving';
      final url = '$baseUrl/table/v1/$profile/$coordsStr'
          '?sources=$sourceIndices&destinations=$destIndices';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok') {
          final durations = data['durations'] as List;
          final distances = data['distances'] as List?;

          final rows = <List<DistanceMatrixEntry>>[];

          for (int i = 0; i < origins.length; i++) {
            final row = <DistanceMatrixEntry>[];
            for (int j = 0; j < destinations.length; j++) {
              final duration = durations[i][j];
              // OSRM table API might not return distances
              // Estimate from duration if not available
              final distance = distances != null
                  ? distances[i][j]
                  : duration * 7.0; // ~25 km/h average

              row.add(DistanceMatrixEntry(
                origin: origins[i],
                destination: destinations[j],
                distanceMeters: (distance as num?)?.toDouble() ?? 0,
                durationSeconds: (duration as num?)?.toDouble() ?? 0,
                isValid: duration != null,
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
      }
    } catch (e) {
      _log('calculateDistanceMatrix error: $e');
    }
    return null;
  }

  @override
  Future<List<LatLng>> snapToRoads(List<LatLng> points) async {
    try {
      final coordsStr =
          points.map((p) => '${p.longitude},${p.latitude}').join(';');
      final url = '$baseUrl/match/v1/driving/$coordsStr'
          '?overview=full&geometries=polyline';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' &&
            data['matchings'] != null &&
            data['matchings'].isNotEmpty) {
          return _decodePolyline(data['matchings'][0]['geometry']);
        }
      }
    } catch (e) {
      _log('snapToRoads error: $e');
    }
    return points; // Return original if snapping fails
  }

  @override
  Future<List<PlaceSuggestion>> getNearbyPlaces(
    LatLng location,
    String type, {
    double radiusMeters = 1000,
  }) async {
    // OSRM doesn't support places search - use Overpass or mock
    _log('getNearbyPlaces: OSRM does not support this');
    return [];
  }

  // ==================== HELPERS ====================

  /// Decode polyline encoded string to list of LatLng
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  void _log(String message) {
    print('[OSRMMapProvider] $message');
  }
}
