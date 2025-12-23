import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Geo Configuration - ENV-based provider selection
///
/// This enables zero-refactor switching between map providers.
/// Set MAP_PROVIDER in .env to switch providers.

enum MapProviderType {
  mock, // Deterministic mock data
  osrm, // Open Source Routing Machine (free)
  google, // Google Maps (requires API key)
}

class GeoConfig {
  static GeoConfig? _instance;
  static bool _dotenvLoaded = false;

  final MapProviderType provider;
  final String? googleMapsApiKey;
  final bool autocompleteEnabled;
  final bool directionsEnabled;
  final bool distanceMatrixEnabled;
  final int cacheExpirationMinutes;
  final int maxCacheEntries;
  final double defaultCitySpeedKmh;
  final double defaultHighwaySpeedKmh;
  final bool debugMode;

  GeoConfig._({
    required this.provider,
    this.googleMapsApiKey,
    this.autocompleteEnabled = false,
    this.directionsEnabled = true,
    this.distanceMatrixEnabled = true,
    this.cacheExpirationMinutes = 30,
    this.maxCacheEntries = 1000,
    this.defaultCitySpeedKmh = 25.0,
    this.defaultHighwaySpeedKmh = 60.0,
    this.debugMode = false,
  });

  /// Initialize dotenv - call this in main() before runApp()
  static Future<void> initialize() async {
    if (!_dotenvLoaded) {
      try {
        await dotenv.load(fileName: ".env");
        _dotenvLoaded = true;
      } catch (e) {
        print('[GeoConfig] Warning: Could not load .env file: $e');
      }
    }
    _instance = _createFromEnv();
  }

  /// Get singleton instance
  static GeoConfig get instance {
    _instance ??= _createFromEnv();
    return _instance!;
  }

  /// Create config from environment variables
  static GeoConfig _createFromEnv() {
    // Read MAP_PROVIDER
    final providerStr = dotenv.env['MAP_PROVIDER'] ?? 'osrm';
    final provider = _parseProvider(providerStr);

    // Read Google Maps API key
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

    // Read feature flags
    final autocomplete = dotenv.env['MAPS_AUTOCOMPLETE_ENABLED'] == 'true';
    final directions = dotenv.env['MAPS_DIRECTIONS_ENABLED'] != 'false';
    final distanceMatrix =
        dotenv.env['MAPS_DISTANCE_MATRIX_ENABLED'] != 'false';

    // Read cache settings
    final cacheExpiration =
        int.tryParse(dotenv.env['CACHE_EXPIRATION_MINUTES'] ?? '') ?? 30;
    final maxCache =
        int.tryParse(dotenv.env['MAX_CACHE_ENTRIES'] ?? '') ?? 1000;

    // Read speeds
    final citySpeed =
        double.tryParse(dotenv.env['DEFAULT_CITY_SPEED_KMH'] ?? '') ?? 25.0;
    final highwaySpeed =
        double.tryParse(dotenv.env['DEFAULT_HIGHWAY_SPEED_KMH'] ?? '') ?? 60.0;

    // Debug mode
    final debug = dotenv.env['DEBUG_MODE'] == 'true';

    return GeoConfig._(
      provider: provider,
      googleMapsApiKey: apiKey,
      autocompleteEnabled: autocomplete,
      directionsEnabled: directions,
      distanceMatrixEnabled: distanceMatrix,
      cacheExpirationMinutes: cacheExpiration,
      maxCacheEntries: maxCache,
      defaultCitySpeedKmh: citySpeed,
      defaultHighwaySpeedKmh: highwaySpeed,
      debugMode: debug,
    );
  }

  static MapProviderType _parseProvider(String value) {
    switch (value.toLowerCase()) {
      case 'mock':
        return MapProviderType.mock;
      case 'google':
        return MapProviderType.google;
      case 'osrm':
      default:
        return MapProviderType.osrm;
    }
  }

  /// Create config from environment variables (legacy factory)
  factory GeoConfig.fromEnvironment() {
    return _createFromEnv();
  }

  /// Create mock config for testing
  factory GeoConfig.mock() {
    return GeoConfig._(
      provider: MapProviderType.mock,
      autocompleteEnabled: true,
      directionsEnabled: true,
      distanceMatrixEnabled: true,
    );
  }

  /// Create Google Maps config
  factory GeoConfig.google(String apiKey) {
    return GeoConfig._(
      provider: MapProviderType.google,
      googleMapsApiKey: apiKey,
      autocompleteEnabled: true,
      directionsEnabled: true,
      distanceMatrixEnabled: true,
    );
  }

  /// Check if Google Maps is configured
  bool get isGoogleMapsEnabled =>
      provider == MapProviderType.google &&
      googleMapsApiKey != null &&
      googleMapsApiKey!.isNotEmpty &&
      googleMapsApiKey != 'your_key_here';

  /// Override config (for testing)
  static void setInstance(GeoConfig config) {
    _instance = config;
  }

  /// Reset to default
  static void reset() {
    _instance = null;
  }

  @override
  String toString() {
    return 'GeoConfig(provider: $provider, googleMaps: $isGoogleMapsEnabled, '
        'autocomplete: $autocompleteEnabled, debug: $debugMode)';
  }
}

/// Time-of-day ETA multipliers
class ETAMultipliers {
  /// Get traffic multiplier based on time of day
  static double getTrafficMultiplier(DateTime time) {
    final hour = time.hour;
    final dayOfWeek = time.weekday;

    // Weekend - less traffic
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      if (hour >= 10 && hour <= 20) return 1.2;
      return 1.0;
    }

    // Weekday rush hours
    if (hour >= 8 && hour <= 10) return 1.5; // Morning rush
    if (hour >= 17 && hour <= 20) return 1.6; // Evening rush
    if (hour >= 13 && hour <= 14) return 1.2; // Lunch
    if (hour >= 22 || hour <= 5) return 0.8; // Night (faster)

    return 1.0;
  }

  /// Get weather multiplier
  static double getWeatherMultiplier(String condition) {
    switch (condition.toLowerCase()) {
      case 'rain':
      case 'rainy':
        return 1.4;
      case 'heavy_rain':
        return 1.8;
      case 'fog':
        return 1.3;
      case 'clear':
      case 'sunny':
      default:
        return 1.0;
    }
  }

  /// Get zone multiplier
  static double getZoneMultiplier(String zoneType) {
    switch (zoneType) {
      case 'airport':
        return 1.2;
      case 'cbd':
      case 'central':
        return 1.3;
      case 'highway':
        return 0.7;
      default:
        return 1.0;
    }
  }
}
