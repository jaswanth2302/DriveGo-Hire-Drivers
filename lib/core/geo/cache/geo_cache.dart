import '../models/geo_models.dart';

/// Geo Cache
///
/// In-memory cache for route calculations, ETAs, and distances.
/// Reduces API calls and improves response times.
///
/// For production, replace with Redis or similar.
class GeoCache {
  static final GeoCache _instance = GeoCache._();
  factory GeoCache() => _instance;
  GeoCache._();

  final Map<String, _CacheEntry<RouteResult>> _routeCache = {};
  final Map<String, _CacheEntry<double>> _etaCache = {};
  final Map<String, _CacheEntry<double>> _distanceCache = {};

  final Duration _defaultExpiration = const Duration(minutes: 30);
  final int _maxEntries = 1000;

  // ==================== ROUTE CACHE ====================

  RouteResult? getRoute(String key) {
    final entry = _routeCache[key];
    if (entry != null && !entry.isExpired) {
      return entry.value;
    }
    if (entry != null) {
      _routeCache.remove(key);
    }
    return null;
  }

  void putRoute(String key, RouteResult route, {Duration? expiration}) {
    _ensureCapacity(_routeCache);
    _routeCache[key] = _CacheEntry(
      value: route,
      expiration: expiration ?? _defaultExpiration,
    );
  }

  // ==================== ETA CACHE ====================

  double? getEta(String key) {
    final entry = _etaCache[key];
    if (entry != null && !entry.isExpired) {
      return entry.value;
    }
    if (entry != null) {
      _etaCache.remove(key);
    }
    return null;
  }

  void putEta(String key, double etaSeconds, {Duration? expiration}) {
    _ensureCapacity(_etaCache);
    _etaCache[key] = _CacheEntry(
      value: etaSeconds,
      expiration: expiration ?? const Duration(minutes: 5),
    );
  }

  // ==================== DISTANCE CACHE ====================

  double? getDistance(String key) {
    final entry = _distanceCache[key];
    if (entry != null && !entry.isExpired) {
      return entry.value;
    }
    if (entry != null) {
      _distanceCache.remove(key);
    }
    return null;
  }

  void putDistance(String key, double distanceMeters, {Duration? expiration}) {
    _ensureCapacity(_distanceCache);
    _distanceCache[key] = _CacheEntry(
      value: distanceMeters,
      expiration: expiration ?? _defaultExpiration,
    );
  }

  // ==================== CACHE MANAGEMENT ====================

  void _ensureCapacity<T>(Map<String, _CacheEntry<T>> cache) {
    if (cache.length >= _maxEntries) {
      // Remove oldest entries
      final keysToRemove = cache.entries.toList()
        ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

      for (int i = 0; i < _maxEntries ~/ 4; i++) {
        cache.remove(keysToRemove[i].key);
      }
    }
  }

  void clearAll() {
    _routeCache.clear();
    _etaCache.clear();
    _distanceCache.clear();
  }

  void clearExpired() {
    _routeCache.removeWhere((_, v) => v.isExpired);
    _etaCache.removeWhere((_, v) => v.isExpired);
    _distanceCache.removeWhere((_, v) => v.isExpired);
  }

  Map<String, int> get stats => {
        'routes': _routeCache.length,
        'etas': _etaCache.length,
        'distances': _distanceCache.length,
      };
}

class _CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  final Duration expiration;

  _CacheEntry({
    required this.value,
    required this.expiration,
  }) : createdAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt) > expiration;
}
