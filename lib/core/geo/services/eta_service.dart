import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/geo_models.dart';
import '../config/geo_config.dart';
import '../cache/geo_cache.dart';

/// ETA Service
///
/// Calculates estimated time of arrival with traffic, weather, and zone adjustments.
/// Independent of map provider - works with any routing data.
final etaServiceProvider = Provider((ref) => ETAService());

class ETAService {
  final GeoCache _cache = GeoCache();

  /// Calculate ETA with all adjustments
  ETAResult calculateETA(
    double baseDurationSeconds, {
    DateTime? departureTime,
    String? weatherCondition,
    String? zoneType,
  }) {
    departureTime ??= DateTime.now();

    // Get multipliers
    final trafficMultiplier =
        ETAMultipliers.getTrafficMultiplier(departureTime);
    final weatherMultiplier = weatherCondition != null
        ? ETAMultipliers.getWeatherMultiplier(weatherCondition)
        : 1.0;
    final zoneMultiplier =
        zoneType != null ? ETAMultipliers.getZoneMultiplier(zoneType) : 1.0;

    // Combined multiplier
    final totalMultiplier =
        trafficMultiplier * weatherMultiplier * zoneMultiplier;

    // Calculate adjusted ETA
    final adjustedSeconds = baseDurationSeconds * totalMultiplier;

    // Determine reason
    String reason = 'Base estimate';
    if (trafficMultiplier > 1.2) reason = 'Heavy traffic expected';
    if (weatherMultiplier > 1.2) reason = 'Weather conditions';
    if (totalMultiplier < 0.9) reason = 'Light traffic expected';

    return ETAResult(
      baseSeconds: baseDurationSeconds,
      adjustedSeconds: adjustedSeconds,
      multiplier: totalMultiplier,
      reason: reason,
      calculatedAt: DateTime.now(),
    );
  }

  /// Calculate ETA from distance (when no route available)
  ETAResult calculateETAFromDistance(
    double distanceMeters, {
    String mode = 'driving',
    DateTime? departureTime,
  }) {
    // Base speeds by mode
    final speeds = {
      'driving': GeoConfig.instance.defaultCitySpeedKmh,
      'walking': 5.0,
      'bicycling': 15.0,
    };

    final speedKmh = speeds[mode] ?? 25.0;
    final baseDurationSeconds = (distanceMeters / 1000 / speedKmh) * 3600;

    return calculateETA(baseDurationSeconds, departureTime: departureTime);
  }

  /// Get ETA with caching
  ETAResult getETACached(String cacheKey, double baseDurationSeconds) {
    final cached = _cache.getEta(cacheKey);
    if (cached != null) {
      return ETAResult(
        baseSeconds: baseDurationSeconds,
        adjustedSeconds: cached,
        multiplier: cached / baseDurationSeconds,
        reason: 'Cached',
        calculatedAt: DateTime.now(),
      );
    }

    final result = calculateETA(baseDurationSeconds);
    _cache.putEta(cacheKey, result.adjustedSeconds);
    return result;
  }

  /// Check if ETA needs recalculation (deviation detected)
  bool needsRecalculation(
    ETAResult previousETA,
    double currentDistanceRemaining,
    double originalDistanceRemaining,
  ) {
    // If distance increased significantly, recalculate
    if (currentDistanceRemaining > originalDistanceRemaining * 1.1) {
      return true;
    }

    // If ETA is stale (> 5 minutes old)
    if (DateTime.now().difference(previousETA.calculatedAt).inMinutes > 5) {
      return true;
    }

    return false;
  }

  /// Get arrival time
  DateTime getArrivalTime(double etaSeconds, {DateTime? from}) {
    from ??= DateTime.now();
    return from.add(Duration(seconds: etaSeconds.round()));
  }

  /// Format ETA for display
  String formatETA(double seconds) {
    if (seconds < 60) return '${seconds.round()} sec';
    if (seconds < 3600) return '${(seconds / 60).round()} min';
    final hours = (seconds / 3600).floor();
    final mins = ((seconds % 3600) / 60).round();
    return '$hours hr $mins min';
  }
}
