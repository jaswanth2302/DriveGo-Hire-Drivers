import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Place model for search results
class Place {
  final String displayName;
  final String shortName;
  final LatLng location;

  Place({
    required this.displayName,
    required this.shortName,
    required this.location,
  });

  factory Place.fromNominatim(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String;
    final parts = displayName.split(',');
    final shortName = parts.length > 2
        ? '${parts[0].trim()}, ${parts[1].trim()}'
        : displayName;

    return Place(
      displayName: displayName,
      shortName: shortName,
      location: LatLng(
        double.parse(json['lat']),
        double.parse(json['lon']),
      ),
    );
  }
}

/// Geocoding service using Nominatim (OpenStreetMap)
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  /// Search for places by query
  Future<List<Place>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '5',
        'countrycodes': 'in', // Limit to India
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Drivo-App'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results.map((r) => Place.fromNominatim(r)).toList();
      }
    } catch (e) {
      // Return empty on error
    }
    return [];
  }

  /// Reverse geocode coordinates to address
  Future<String?> reverseGeocode(LatLng location) async {
    try {
      final uri = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'format': 'json',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Drivo-App'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['display_name'] as String?;
      }
    } catch (e) {
      // Return null on error
    }
    return null;
  }

  /// Get address string from coordinates (convenience method)
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    final location = LatLng(lat, lng);
    final address = await reverseGeocode(location);
    if (address != null) {
      // Return first 2 parts for short display
      final parts = address.split(',');
      if (parts.length >= 2) {
        return '${parts[0].trim()}, ${parts[1].trim()}';
      }
      return address;
    }
    return 'Bangalore, Karnataka'; // Default fallback
  }
}

/// Provider for GeocodingService
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});
