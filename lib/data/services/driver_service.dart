import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// ============================================================
/// DRIVER SERVICE - Edge Function Integration for Driver App
/// ============================================================
/// Handles driver-specific operations:
/// - Heartbeat/location updates
/// - Going online/offline
/// - Responding to ride requests
/// - Trip management

class DriverService {
  final SupabaseClient _client;
  Timer? _heartbeatTimer;
  bool _isOnline = false;

  DriverService(this._client);

  /// Check if driver is currently online
  bool get isOnline => _isOnline;

  // ==================== HEARTBEAT ====================

  /// Start sending heartbeats (call when driver goes online)
  /// Calls: driver-heartbeat Edge Function every 30 seconds
  void startHeartbeat({
    required double Function() getLatitude,
    required double Function() getLongitude,
    double Function()? getHeading,
    double Function()? getSpeed,
    int Function()? getBatteryLevel,
    String? appVersion,
  }) {
    _isOnline = true;

    // Send initial heartbeat
    _sendHeartbeat(
      lat: getLatitude(),
      lng: getLongitude(),
      heading: getHeading?.call(),
      speed: getSpeed?.call(),
      batteryLevel: getBatteryLevel?.call(),
      appVersion: appVersion,
    );

    // Start timer for periodic heartbeats
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline) {
        _sendHeartbeat(
          lat: getLatitude(),
          lng: getLongitude(),
          heading: getHeading?.call(),
          speed: getSpeed?.call(),
          batteryLevel: getBatteryLevel?.call(),
          appVersion: appVersion,
        );
      }
    });
  }

  /// Stop sending heartbeats (call when driver goes offline)
  void stopHeartbeat() {
    _isOnline = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Send a single heartbeat
  Future<HeartbeatResult?> _sendHeartbeat({
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    int? batteryLevel,
    String? appVersion,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'driver-heartbeat',
        body: {
          'lat': lat,
          'lng': lng,
          'heading': heading,
          'speed': speed,
          'accuracy': accuracy,
          'battery_level': batteryLevel,
          'app_version': appVersion,
        },
      );

      if (response.status == 200 && response.data['success'] == true) {
        return HeartbeatResult.fromJson(response.data['data']);
      }
    } catch (e) {
      // Silently fail - heartbeat is best-effort
      print('Heartbeat failed: $e');
    }
    return null;
  }

  // ==================== ONLINE/OFFLINE STATUS ====================

  /// Go online (start accepting rides)
  Future<void> goOnline({
    required double lat,
    required double lng,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await _client.from('driver_profiles').update({
      'status': 'online',
      'current_lat': lat,
      'current_lng': lng,
      'last_location_update': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    _isOnline = true;
  }

  /// Go offline (stop accepting rides)
  Future<void> goOffline() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    stopHeartbeat();

    await _client.from('driver_profiles').update({
      'status': 'offline',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    // End active session
    await _client
        .from('driver_sessions')
        .update({
          'ended_at': DateTime.now().toIso8601String(),
          'end_reason': 'manual_offline',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('driver_id', userId)
        .isFilter('ended_at', null);

    _isOnline = false;
  }

  // ==================== MATCH RESPONSES ====================

  /// Accept a ride request
  Future<void> acceptRide(String matchAttemptId) async {
    await _client.from('ride_match_attempts').update({
      'response': 'accepted',
      'responded_at': DateTime.now().toIso8601String(),
    }).eq('id', matchAttemptId);
  }

  /// Reject a ride request
  Future<void> rejectRide(String matchAttemptId, {String? reason}) async {
    await _client.from('ride_match_attempts').update({
      'response': 'rejected',
      'responded_at': DateTime.now().toIso8601String(),
      'rejection_reason': reason,
    }).eq('id', matchAttemptId);
  }

  // ==================== TRIP ACTIONS ====================

  /// Notify that driver has started towards pickup
  Future<void> startEnRoute(String bookingId,
      {double? lat, double? lng}) async {
    await _client.functions.invoke(
      'update-ride-status',
      body: {
        'booking_id': bookingId,
        'new_status': 'driver_en_route',
        'lat': lat,
        'lng': lng,
      },
    );
  }

  /// Notify that driver has arrived at pickup
  Future<void> arrivedAtPickup(String bookingId,
      {double? lat, double? lng}) async {
    await _client.functions.invoke(
      'update-ride-status',
      body: {
        'booking_id': bookingId,
        'new_status': 'driver_arrived',
        'lat': lat,
        'lng': lng,
      },
    );
  }

  /// Start trip after OTP verification
  Future<OtpVerificationResult> startTrip(String bookingId, String otp,
      {double? lat, double? lng}) async {
    final response = await _client.functions.invoke(
      'verify-ride-otp',
      body: {
        'booking_id': bookingId,
        'otp': otp,
        'lat': lat,
        'lng': lng,
      },
    );

    if (response.status != 200 || response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to verify OTP');
    }

    return OtpVerificationResult.fromJson(response.data['data']);
  }

  /// Complete the trip
  Future<FareFinalizationResult> completeTrip(
    String bookingId, {
    double? actualDistanceKm,
    double? actualDurationMinutes,
    double? lat,
    double? lng,
  }) async {
    final response = await _client.functions.invoke(
      'finalize-ride-fare',
      body: {
        'booking_id': bookingId,
        'actual_distance_km': actualDistanceKm,
        'actual_duration_minutes': actualDurationMinutes,
        'lat': lat,
        'lng': lng,
      },
    );

    if (response.status != 200 || response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to finalize fare');
    }

    return FareFinalizationResult.fromJson(response.data['data']);
  }

  // ==================== REALTIME SUBSCRIPTIONS ====================

  /// Watch for incoming ride requests
  Stream<List<Map<String, dynamic>>> watchRideRequests() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client
        .from('ride_match_attempts')
        .stream(primaryKey: ['id']).order('sent_at', ascending: false);
  }

  /// Watch assigned bookings
  Stream<List<Map<String, dynamic>>> watchAssignedBookings() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client.from('ride_bookings').stream(
        primaryKey: ['id']).order('driver_assigned_at', ascending: false);
  }

  // ==================== DRIVER PROFILE ====================

  /// Get driver profile
  Future<Map<String, dynamic>?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    return await _client
        .from('driver_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  /// Get today's earnings
  Future<Map<String, dynamic>?> getTodayEarnings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final today = DateTime.now().toIso8601String().split('T')[0];

    return await _client
        .from('driver_daily_metrics')
        .select()
        .eq('driver_id', userId)
        .eq('date', today)
        .maybeSingle();
  }

  /// Get trip history
  Future<List<Map<String, dynamic>>> getTripHistory({int limit = 20}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    return await _client
        .from('ride_bookings')
        .select('*, customer:profiles(name, phone, photo_url)')
        .eq('driver_id', userId)
        .inFilter('status', ['trip_completed', 'payment_completed'])
        .order('trip_completed_at', ascending: false)
        .limit(limit);
  }

  /// Dispose resources
  void dispose() {
    stopHeartbeat();
  }
}

// ==================== RESPONSE MODELS ====================

class HeartbeatResult {
  final String sessionId;
  final String status;
  final String? activeBookingId;

  HeartbeatResult({
    required this.sessionId,
    required this.status,
    this.activeBookingId,
  });

  factory HeartbeatResult.fromJson(Map<String, dynamic> json) {
    return HeartbeatResult(
      sessionId: json['session_id'] ?? '',
      status: json['status'] ?? '',
      activeBookingId: json['active_booking_id'],
    );
  }
}

class OtpVerificationResult {
  final String bookingId;
  final bool verified;
  final String newStatus;
  final String tripStartedAt;

  OtpVerificationResult({
    required this.bookingId,
    required this.verified,
    required this.newStatus,
    required this.tripStartedAt,
  });

  factory OtpVerificationResult.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResult(
      bookingId: json['booking_id'] ?? '',
      verified: json['verified'] ?? false,
      newStatus: json['new_status'] ?? '',
      tripStartedAt: json['trip_started_at'] ?? '',
    );
  }
}

class FareFinalizationResult {
  final String bookingId;
  final double estimatedFare;
  final double finalFare;
  final double tipAmount;
  final double totalAmount;
  final String paymentId;
  final String status;

  FareFinalizationResult({
    required this.bookingId,
    required this.estimatedFare,
    required this.finalFare,
    required this.tipAmount,
    required this.totalAmount,
    required this.paymentId,
    required this.status,
  });

  factory FareFinalizationResult.fromJson(Map<String, dynamic> json) {
    return FareFinalizationResult(
      bookingId: json['booking_id'] ?? '',
      estimatedFare: (json['estimated_fare'] ?? 0).toDouble(),
      finalFare: (json['final_fare'] ?? 0).toDouble(),
      tipAmount: (json['tip_amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      paymentId: json['payment_id'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

// ==================== RIVERPOD PROVIDERS ====================

/// Provider for DriverService
final driverServiceProvider = Provider<DriverService>((ref) {
  final service = DriverService(ref.watch(supabaseClientProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for driver profile
final driverProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(driverServiceProvider);
  return await service.getProfile();
});

/// Provider for today's earnings
final todayEarningsProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(driverServiceProvider);
  return await service.getTodayEarnings();
});

/// Stream provider for incoming ride requests
final rideRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(driverServiceProvider);
  return service.watchRideRequests();
});

/// Stream provider for assigned bookings
final assignedBookingsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(driverServiceProvider);
  return service.watchAssignedBookings();
});
