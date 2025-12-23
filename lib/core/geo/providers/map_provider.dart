import 'package:latlong2/latlong.dart';
import '../models/geo_models.dart';

/// Abstract Map Provider Interface
///
/// This is the core abstraction that allows switching between
/// Mock, OSRM, Google Maps, or any other provider.
///
/// All map operations go through this interface.
abstract class MapProvider {
  /// Get provider name for logging
  String get providerName;

  /// Check if provider is available
  Future<bool> isAvailable();

  /// Get autocomplete suggestions for a search query
  Future<List<PlaceSuggestion>> getAutocompleteSuggestions(
    String query, {
    LatLng? nearLocation,
    int maxResults = 5,
  });

  /// Convert address text to coordinates
  Future<GeoAddress?> geocodeAddress(String address);

  /// Convert coordinates to address
  Future<GeoAddress?> reverseGeocode(LatLng location);

  /// Calculate route between two points
  Future<RouteResult?> calculateRoute(
    LatLng origin,
    LatLng destination, {
    List<LatLng>? waypoints,
    String mode = 'driving', // driving, walking, bicycling
  });

  /// Calculate distance matrix between multiple origins and destinations
  Future<DistanceMatrix?> calculateDistanceMatrix(
    List<LatLng> origins,
    List<LatLng> destinations, {
    String mode = 'driving',
  });

  /// Snap a polyline to roads
  Future<List<LatLng>> snapToRoads(List<LatLng> points);

  /// Get nearby places of a type
  Future<List<PlaceSuggestion>> getNearbyPlaces(
    LatLng location,
    String type, {
    double radiusMeters = 1000,
  });
}

/// Provider factory - creates the appropriate provider based on config
class MapProviderFactory {
  static MapProvider? _cachedProvider;

  /// Get the configured map provider
  static MapProvider getProvider() {
    // Return cached provider if available
    if (_cachedProvider != null) return _cachedProvider!;

    // Import dynamically based on config
    // For now, default to OSRM
    // In production, read from GeoConfig
    _cachedProvider = _createOSRMProvider();
    return _cachedProvider!;
  }

  static MapProvider _createOSRMProvider() {
    // This will be imported from osrm_map_provider.dart
    // For now, return a placeholder that will be replaced
    throw UnimplementedError('Import OSRMMapProvider');
  }

  /// Set custom provider (for testing)
  static void setProvider(MapProvider provider) {
    _cachedProvider = provider;
  }

  /// Clear cached provider
  static void clearCache() {
    _cachedProvider = null;
  }
}
