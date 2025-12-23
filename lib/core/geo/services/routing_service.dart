import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/geo_models.dart';
import '../providers/map_provider.dart';
import '../providers/osrm_map_provider.dart';
import '../config/geo_config.dart';
import '../cache/geo_cache.dart';

/// Routing Service
///
/// Handles all route calculation with caching and provider abstraction.
/// Used by ride booking, trip tracking, and ETA calculations.
final routingServiceProvider = Provider((ref) => RoutingService());

class RoutingService {
  late final MapProvider _provider;
  final GeoCache _cache = GeoCache();

  RoutingService() {
    // Initialize provider based on config
    final config = GeoConfig.instance;
    switch (config.provider) {
      case MapProviderType.google:
        // TODO: Use GoogleMapProvider when available
        _provider = OSRMMapProvider();
        break;
      case MapProviderType.osrm:
        _provider = OSRMMapProvider();
        break;
      case MapProviderType.mock:
      default:
        _provider = OSRMMapProvider(); // Use OSRM as default
    }
  }

  /// Calculate route between two points
  /// Uses cache if available
  Future<RouteResult?> getRoute(
    LatLng origin,
    LatLng destination, {
    List<LatLng>? waypoints,
    String mode = 'driving',
    bool useCache = true,
  }) async {
    // Check cache first
    if (useCache) {
      final cacheKey = _routeCacheKey(origin, destination, waypoints, mode);
      final cached = _cache.getRoute(cacheKey);
      if (cached != null) {
        print('[RoutingService] Cache hit for route');
        return cached;
      }
    }

    // Calculate route
    final route = await _provider.calculateRoute(
      origin,
      destination,
      waypoints: waypoints,
      mode: mode,
    );

    // Cache result
    if (route != null && useCache) {
      final cacheKey = _routeCacheKey(origin, destination, waypoints, mode);
      _cache.putRoute(cacheKey, route);
    }

    return route;
  }

  /// Calculate multiple routes (for comparing ride types)
  Future<List<RouteResult?>> getRoutes(
    LatLng origin,
    LatLng destination,
    List<String> modes,
  ) async {
    final futures =
        modes.map((mode) => getRoute(origin, destination, mode: mode));
    return Future.wait(futures);
  }

  /// Get route with waypoints (multi-stop trips)
  Future<RouteResult?> getMultiStopRoute(
    LatLng origin,
    List<LatLng> stops,
    LatLng destination, {
    String mode = 'driving',
  }) async {
    return getRoute(origin, destination, waypoints: stops, mode: mode);
  }

  /// Get distance matrix for driver matching
  Future<DistanceMatrix?> getDistanceMatrix(
    List<LatLng> origins,
    List<LatLng> destinations, {
    String mode = 'driving',
  }) async {
    return _provider.calculateDistanceMatrix(origins, destinations, mode: mode);
  }

  /// Snap GPS points to roads (for accurate tracking)
  Future<List<LatLng>> snapToRoads(List<LatLng> points) async {
    return _provider.snapToRoads(points);
  }

  /// Generate cache key
  String _routeCacheKey(
    LatLng origin,
    LatLng destination,
    List<LatLng>? waypoints,
    String mode,
  ) {
    final waypointsStr =
        waypoints?.map((w) => '${w.latitude},${w.longitude}').join('|') ?? '';
    return 'route_${origin.latitude}_${origin.longitude}_'
        '${destination.latitude}_${destination.longitude}_'
        '${waypointsStr}_$mode';
  }
}
