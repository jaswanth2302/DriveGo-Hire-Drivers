import 'package:latlong2/latlong.dart';
import '../models/geo_models.dart';
import 'map_provider.dart';

/// Google Maps Provider (STUB)
///
/// This is a placeholder for future Google Maps integration.
/// When Google Maps API key is available:
/// 1. Add google_maps_flutter package
/// 2. Implement all methods with Google APIs
/// 3. Switch provider in GeoConfig
///
/// Zero refactoring required - just implement and enable.
class GoogleMapProvider implements MapProvider {
  final String apiKey;

  GoogleMapProvider({required this.apiKey});

  @override
  String get providerName => 'Google';

  @override
  Future<bool> isAvailable() async {
    // TODO: Validate API key with a simple request
    return apiKey.isNotEmpty;
  }

  @override
  Future<List<PlaceSuggestion>> getAutocompleteSuggestions(
    String query, {
    LatLng? nearLocation,
    int maxResults = 5,
  }) async {
    // TODO: Implement with Places Autocomplete API
    // https://maps.googleapis.com/maps/api/place/autocomplete/json
    throw UnimplementedError('Google Maps autocomplete not yet implemented');
  }

  @override
  Future<GeoAddress?> geocodeAddress(String address) async {
    // TODO: Implement with Geocoding API
    // https://maps.googleapis.com/maps/api/geocode/json
    throw UnimplementedError('Google Maps geocoding not yet implemented');
  }

  @override
  Future<GeoAddress?> reverseGeocode(LatLng location) async {
    // TODO: Implement with Geocoding API
    throw UnimplementedError(
        'Google Maps reverse geocoding not yet implemented');
  }

  @override
  Future<RouteResult?> calculateRoute(
    LatLng origin,
    LatLng destination, {
    List<LatLng>? waypoints,
    String mode = 'driving',
  }) async {
    // TODO: Implement with Directions API
    // https://maps.googleapis.com/maps/api/directions/json
    throw UnimplementedError('Google Maps directions not yet implemented');
  }

  @override
  Future<DistanceMatrix?> calculateDistanceMatrix(
    List<LatLng> origins,
    List<LatLng> destinations, {
    String mode = 'driving',
  }) async {
    // TODO: Implement with Distance Matrix API
    // https://maps.googleapis.com/maps/api/distancematrix/json
    throw UnimplementedError('Google Maps distance matrix not yet implemented');
  }

  @override
  Future<List<LatLng>> snapToRoads(List<LatLng> points) async {
    // TODO: Implement with Roads API
    // https://roads.googleapis.com/v1/snapToRoads
    throw UnimplementedError('Google Maps snap to roads not yet implemented');
  }

  @override
  Future<List<PlaceSuggestion>> getNearbyPlaces(
    LatLng location,
    String type, {
    double radiusMeters = 1000,
  }) async {
    // TODO: Implement with Places Nearby Search API
    throw UnimplementedError('Google Maps nearby places not yet implemented');
  }
}
