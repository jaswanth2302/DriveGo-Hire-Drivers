import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Repository for driver-related database operations
class DriverRepository {
  final SupabaseClient _client;

  DriverRepository(this._client);

  // ==================== DRIVER PROFILE ====================

  /// Get driver by ID
  Future<Map<String, dynamic>?> getDriver(String driverId) async {
    return await _client.driverProfiles
        .select()
        .eq('id', driverId)
        .maybeSingle();
  }

  /// Get available drivers near location
  Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
  }) async {
    // Simple bounding box query (for production, use PostGIS)
    final latDelta = radiusKm / 111.0; // ~111km per degree latitude
    final lngDelta = radiusKm / (111.0 * 0.7); // Approximate for mid-latitudes

    final response = await _client.driverProfiles
        .select()
        .eq('status', 'online')
        .eq('kyc_status', 'verified')
        .gte('current_lat', lat - latDelta)
        .lte('current_lat', lat + latDelta)
        .gte('current_lng', lng - lngDelta)
        .lte('current_lng', lng + lngDelta)
        .order('rating', ascending: false)
        .limit(10);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Update driver status
  Future<void> updateDriverStatus(String driverId, String status) async {
    await _client.driverProfiles.update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', driverId);
  }

  /// Update driver location
  Future<void> updateDriverLocation({
    required String driverId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) async {
    await _client.driverProfiles.update({
      'current_lat': lat,
      'current_lng': lng,
      'current_heading': heading,
      'last_location_update': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', driverId);
  }

  /// Record driver location history
  Future<void> recordLocationHistory({
    required String driverId,
    String? bookingId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    await _client.driverLocationHistory.insert({
      'driver_id': driverId,
      'booking_id': bookingId,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
    });
  }

  // ==================== DRIVER EARNINGS ====================

  /// Get driver earnings for today
  Future<Map<String, dynamic>?> getTodayEarnings(String driverId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    return await _client.driverEarnings
        .select()
        .eq('driver_id', driverId)
        .eq('date', today)
        .maybeSingle();
  }

  /// Get driver earnings summary
  Future<Map<String, dynamic>> getEarningsSummary(String driverId) async {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    final weekStart = now
        .subtract(Duration(days: now.weekday - 1))
        .toIso8601String()
        .split('T')[0];
    final monthStart =
        DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];

    // Get today's earnings
    final todayData = await _client.driverEarnings
        .select('total_earnings')
        .eq('driver_id', driverId)
        .eq('date', today)
        .maybeSingle();

    // Get week's earnings
    final weekData = await _client.driverEarnings
        .select('total_earnings')
        .eq('driver_id', driverId)
        .gte('date', weekStart);

    // Get month's earnings
    final monthData = await _client.driverEarnings
        .select('total_earnings')
        .eq('driver_id', driverId)
        .gte('date', monthStart);

    double weekTotal = 0;
    for (var row in weekData) {
      weekTotal += (row['total_earnings'] as num).toDouble();
    }

    double monthTotal = 0;
    for (var row in monthData) {
      monthTotal += (row['total_earnings'] as num).toDouble();
    }

    return {
      'today': todayData?['total_earnings'] ?? 0,
      'week': weekTotal,
      'month': monthTotal,
    };
  }

  /// Get driver bonuses
  Future<List<Map<String, dynamic>>> getDriverBonuses(String driverId,
      {int limit = 10}) async {
    final response = await _client.driverBonuses
        .select()
        .eq('driver_id', driverId)
        .order('earned_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== DRIVER AVAILABILITY ====================

  /// Get driver availability schedule
  Future<List<Map<String, dynamic>>> getAvailability(String driverId) async {
    final response = await _client.driverAvailability
        .select()
        .eq('driver_id', driverId)
        .order('day_of_week');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Set driver availability for a day
  Future<void> setAvailability({
    required String driverId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    bool isAvailable = true,
  }) async {
    await _client.driverAvailability.upsert({
      'driver_id': driverId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_available': isAvailable,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get driver time off
  Future<List<Map<String, dynamic>>> getTimeOff(String driverId) async {
    final response = await _client.driverTimeOff
        .select()
        .eq('driver_id', driverId)
        .gte('end_date', DateTime.now().toIso8601String().split('T')[0])
        .order('start_date');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Request time off
  Future<void> requestTimeOff({
    required String driverId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    await _client.driverTimeOff.insert({
      'driver_id': driverId,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'reason': reason,
      'is_approved': false,
    });
  }

  // ==================== KYC ====================

  /// Get driver KYC documents
  Future<List<Map<String, dynamic>>> getKycDocuments(String driverId) async {
    final response =
        await _client.driverKycDocuments.select().eq('driver_id', driverId);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Upload KYC document
  Future<void> uploadKycDocument({
    required String driverId,
    required String documentType,
    required String documentNumber,
    String? documentUrl,
  }) async {
    await _client.driverKycDocuments.upsert({
      'driver_id': driverId,
      'document_type': documentType,
      'document_number': documentNumber,
      'document_url': documentUrl,
      'is_verified': false,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

// Riverpod provider
final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(ref.watch(supabaseClientProvider));
});
