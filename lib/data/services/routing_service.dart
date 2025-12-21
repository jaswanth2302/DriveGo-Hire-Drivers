import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Route information
class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;

  RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

/// Routing service using OSRM (Open Source Routing Machine)
class RoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org';

  /// Get driving route between two points
  Future<RouteInfo?> getRoute(LatLng from, LatLng to) async {
    try {
      final coords =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final uri = Uri.parse('$_baseUrl/route/v1/driving/$coords').replace(
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;

          final points = geometry.map<LatLng>((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          final distanceMeters = route['distance'] as num;
          final durationSeconds = route['duration'] as num;

          return RouteInfo(
            points: points,
            distanceKm: distanceMeters / 1000,
            durationMinutes: (durationSeconds / 60).round(),
          );
        }
      }
    } catch (e) {
      // Return null on error
    }
    return null;
  }

  /// Calculate fare based on distance
  double calculateFare(double distanceKm, String serviceType) {
    const baseFare = 50.0;
    const perKmRate = 12.0;

    double multiplier = 1.0;
    switch (serviceType) {
      case 'hourly':
        multiplier = 1.0;
        break;
      case 'half_day':
        multiplier = 0.9; // 10% discount
        break;
      case 'full_day':
        multiplier = 0.8; // 20% discount
        break;
    }

    return (baseFare + (distanceKm * perKmRate)) * multiplier;
  }
}

/// Provider for RoutingService
final routingServiceProvider = Provider<RoutingService>((ref) {
  return RoutingService();
});
