import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// ============================================================
/// RIDE BOOKING SERVICE - Edge Function Integration
/// ============================================================
/// Connects Flutter frontend to Supabase Edge Functions for:
/// - Fare estimation
/// - Ride booking
/// - Driver matching
/// - Status updates
/// - Live tracking via Realtime

class RideBookingService {
  final SupabaseClient _client;

  RideBookingService(this._client);

  // ==================== FARE ESTIMATION ====================

  /// Estimate fare for a ride without creating booking
  /// Calls: estimate-ride-fare Edge Function
  Future<FareEstimate> estimateFare({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    required String rideTypeId,
    String cityCode = 'BLR',
  }) async {
    final response = await _client.functions.invoke(
      'estimate-ride-fare',
      body: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'drop_lat': dropLat,
        'drop_lng': dropLng,
        'ride_type_id': rideTypeId,
        'city_code': cityCode,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to estimate fare: ${response.data}');
    }

    final data = response.data;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    return FareEstimate.fromJson(data['data']);
  }

  // ==================== BOOKING CREATION ====================

  /// Create a new ride booking
  /// Calls: create-ride-booking Edge Function
  Future<RideBookingResult> createBooking({
    required String pickupAddress,
    String? pickupShortName,
    required double pickupLat,
    required double pickupLng,
    required String dropAddress,
    String? dropShortName,
    required double dropLat,
    required double dropLng,
    required String rideTypeId,
    required String timingMode, // 'now', 'tomorrow', 'scheduled'
    DateTime? scheduledTime,
    required double distanceKm,
    required int durationMinutes,
    required double estimatedFare,
    double surgeMultiplier = 1.0,
    String? routePolyline,
    String paymentMethod = 'cash',
  }) async {
    final body = {
      'pickup_address': pickupAddress,
      'pickup_short_name': pickupShortName,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'drop_address': dropAddress,
      'drop_short_name': dropShortName,
      'drop_lat': dropLat,
      'drop_lng': dropLng,
      'ride_type_id': rideTypeId,
      'timing_mode': timingMode,
      'distance_km': distanceKm,
      'duration_minutes': durationMinutes,
      'estimated_fare': estimatedFare,
      'surge_multiplier': surgeMultiplier,
      'route_polyline': routePolyline,
      'payment_method': paymentMethod,
    };

    if (scheduledTime != null) {
      body['scheduled_time'] = scheduledTime.toIso8601String();
    }

    // Ensure user is authenticated before calling Edge Function
    final session = _client.auth.currentSession;
    if (session == null) {
      throw Exception('Not authenticated. Please login first.');
    }

    final response = await _client.functions.invoke(
      'create-ride-booking',
      body: body,
    );

    if (response.status != 200) {
      final errorData = response.data;
      final errorMsg = errorData is Map
          ? errorData['error'] ?? 'Unknown error'
          : 'Status ${response.status}';
      throw Exception('Failed to create booking: $errorMsg');
    }

    final data = response.data;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    return RideBookingResult.fromJson(data['data']);
  }

  // ==================== DRIVER MATCHING ====================

  /// Trigger driver matching for a booking
  /// Calls: match-driver-for-ride Edge Function
  /// Note: Usually called automatically after booking creation
  Future<MatchResult> matchDriver({
    required String bookingId,
    double searchRadiusKm = 3.0,
    int maxAttempts = 10,
  }) async {
    final response = await _client.functions.invoke(
      'match-driver-for-ride',
      body: {
        'booking_id': bookingId,
        'search_radius_km': searchRadiusKm,
        'max_attempts': maxAttempts,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to match driver: ${response.data}');
    }

    final data = response.data;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    return MatchResult.fromJson(data['data']);
  }

  // ==================== STATUS UPDATES ====================

  /// Update ride status (state machine)
  /// Calls: update-ride-status Edge Function
  Future<StatusUpdateResult> updateStatus({
    required String bookingId,
    required String newStatus,
    double? lat,
    double? lng,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _client.functions.invoke(
      'update-ride-status',
      body: {
        'booking_id': bookingId,
        'new_status': newStatus,
        'lat': lat,
        'lng': lng,
        'metadata': metadata ?? {},
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to update status: ${response.data}');
    }

    final data = response.data;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    return StatusUpdateResult.fromJson(data['data']);
  }

  // ==================== OTP VERIFICATION ====================

  /// Verify OTP to start trip (driver only)
  /// Calls: verify-ride-otp Edge Function
  Future<OtpVerificationResult> verifyOtp({
    required String bookingId,
    required String otp,
    double? lat,
    double? lng,
  }) async {
    final response = await _client.functions.invoke(
      'verify-ride-otp',
      body: {
        'booking_id': bookingId,
        'otp': otp,
        'lat': lat,
        'lng': lng,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to verify OTP: ${response.data}');
    }

    final data = response.data;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    return OtpVerificationResult.fromJson(data['data']);
  }

  // ==================== FARE FINALIZATION ====================

  /// Finalize fare after trip completion
  /// Calls: finalize-ride-fare Edge Function
  Future<FareFinalizationResult> finalizeFare({
    required String bookingId,
    double? actualDistanceKm,
    double? actualDurationMinutes,
    double tipAmount = 0,
    double? lat,
    double? lng,
  }) async {
    final response = await _client.functions.invoke(
      'finalize-ride-fare',
      body: {
        'booking_id': bookingId,
        'actual_distance_km': actualDistanceKm,
        'actual_duration_minutes': actualDurationMinutes,
        'tip_amount': tipAmount,
        'lat': lat,
        'lng': lng,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to finalize fare: ${response.data}');
    }

    final data = response.data;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    return FareFinalizationResult.fromJson(data['data']);
  }

  // ==================== CANCELLATION ====================

  /// Cancel a ride booking
  /// Calls: cancel-ride Edge Function
  Future<CancellationResult> cancelRide({
    required String bookingId,
    String? reason,
    double? lat,
    double? lng,
  }) async {
    final response = await _client.functions.invoke(
      'cancel-ride',
      body: {
        'booking_id': bookingId,
        'reason': reason,
        'lat': lat,
        'lng': lng,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to cancel ride: ${response.data}');
    }

    final data = response.data;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    return CancellationResult.fromJson(data['data']);
  }

  // ==================== REALTIME SUBSCRIPTIONS ====================

  /// Subscribe to booking status changes
  Stream<Map<String, dynamic>> watchBooking(String bookingId) {
    return _client
        .from('ride_bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .map((list) => list.isNotEmpty ? list.first : {});
  }

  /// Subscribe to driver location during ride
  Stream<List<Map<String, dynamic>>> watchDriverLocation(String driverId) {
    return _client
        .from('driver_location_history')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('recorded_at', ascending: false)
        .limit(1);
  }

  /// Subscribe to match attempts for a booking
  Stream<List<Map<String, dynamic>>> watchMatchAttempts(String bookingId) {
    return _client
        .from('ride_match_attempts')
        .stream(primaryKey: ['id'])
        .eq('ride_booking_id', bookingId)
        .order('sent_at', ascending: false);
  }

  /// Subscribe to ride events
  Stream<List<Map<String, dynamic>>> watchRideEvents(String bookingId) {
    return _client
        .from('ride_events')
        .stream(primaryKey: ['id'])
        .eq('ride_booking_id', bookingId)
        .order('created_at', ascending: false);
  }

  // ==================== DIRECT QUERIES ====================

  /// Get booking by ID
  Future<Map<String, dynamic>?> getBooking(String bookingId) async {
    return await _client
        .from('ride_bookings')
        .select()
        .eq('id', bookingId)
        .maybeSingle();
  }

  /// Get user's active booking (if any)
  Future<Map<String, dynamic>?> getActiveBooking() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    return await _client
        .from('ride_bookings')
        .select()
        .eq('customer_id', userId)
        .inFilter('status', [
          'searching',
          'driver_assigned',
          'driver_en_route',
          'driver_arrived',
          'trip_started',
          'trip_in_progress',
        ])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  /// Get booking history
  Future<List<Map<String, dynamic>>> getBookingHistory({int limit = 20}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    return await _client
        .from('ride_bookings')
        .select('*, driver:driver_profiles(name, phone, rating, photo_url)')
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  /// Get available ride types
  Future<List<Map<String, dynamic>>> getRideTypes() async {
    return await _client
        .from('ride_types')
        .select()
        .eq('is_active', true)
        .order('display_order');
  }

  /// Get driver profile by ID
  Future<Map<String, dynamic>?> getDriverProfile(String driverId) async {
    return await _client
        .from('driver_profiles')
        .select(
            'id, name, phone, photo_url, rating, total_trips, status, current_lat, current_lng')
        .eq('id', driverId)
        .maybeSingle();
  }

  /// Get nearby online drivers
  Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
  }) async {
    // Get all online drivers and filter by distance client-side
    // PostGIS would be better for production
    final drivers = await _client
        .from('driver_profiles')
        .select(
            'id, name, photo_url, rating, total_trips, current_lat, current_lng')
        .eq('status', 'online')
        .not('current_lat', 'is', null);

    return drivers;
  }
}

// ==================== RESPONSE MODELS ====================

class FareEstimate {
  final String rideTypeId;
  final String rideTypeName;
  final double distanceKm;
  final int durationMinutes;
  final double baseFare;
  final double distanceCharge;
  final double timeCharge;
  final double surgeMultiplier;
  final double surgeCharge;
  final double estimatedFare;
  final double minFare;
  final String currency;

  FareEstimate({
    required this.rideTypeId,
    required this.rideTypeName,
    required this.distanceKm,
    required this.durationMinutes,
    required this.baseFare,
    required this.distanceCharge,
    required this.timeCharge,
    required this.surgeMultiplier,
    required this.surgeCharge,
    required this.estimatedFare,
    required this.minFare,
    required this.currency,
  });

  factory FareEstimate.fromJson(Map<String, dynamic> json) {
    return FareEstimate(
      rideTypeId: json['ride_type_id'] ?? '',
      rideTypeName: json['ride_type_name'] ?? '',
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      durationMinutes: json['duration_minutes'] ?? 0,
      baseFare: (json['base_fare'] ?? 0).toDouble(),
      distanceCharge: (json['distance_charge'] ?? 0).toDouble(),
      timeCharge: (json['time_charge'] ?? 0).toDouble(),
      surgeMultiplier: (json['surge_multiplier'] ?? 1.0).toDouble(),
      surgeCharge: (json['surge_charge'] ?? 0).toDouble(),
      estimatedFare: (json['estimated_fare'] ?? 0).toDouble(),
      minFare: (json['min_fare'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'INR',
    );
  }
}

class RideBookingResult {
  final String bookingId;
  final String status;
  final String otp;
  final String createdAt;

  RideBookingResult({
    required this.bookingId,
    required this.status,
    required this.otp,
    required this.createdAt,
  });

  factory RideBookingResult.fromJson(Map<String, dynamic> json) {
    return RideBookingResult(
      bookingId: json['booking_id'] ?? '',
      status: json['status'] ?? '',
      otp: json['otp'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class MatchResult {
  final bool matched;
  final String? driverId;
  final String? driverName;
  final double? driverRating;
  final int? etaMinutes;
  final int attemptsMade;

  MatchResult({
    required this.matched,
    this.driverId,
    this.driverName,
    this.driverRating,
    this.etaMinutes,
    required this.attemptsMade,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      matched: json['matched'] ?? false,
      driverId: json['driver_id'],
      driverName: json['driver_name'],
      driverRating: json['driver_rating']?.toDouble(),
      etaMinutes: json['eta_minutes'],
      attemptsMade: json['attempts_made'] ?? 0,
    );
  }
}

class StatusUpdateResult {
  final String bookingId;
  final String oldStatus;
  final String newStatus;
  final String updatedAt;

  StatusUpdateResult({
    required this.bookingId,
    required this.oldStatus,
    required this.newStatus,
    required this.updatedAt,
  });

  factory StatusUpdateResult.fromJson(Map<String, dynamic> json) {
    return StatusUpdateResult(
      bookingId: json['booking_id'] ?? '',
      oldStatus: json['old_status'] ?? '',
      newStatus: json['new_status'] ?? '',
      updatedAt: json['updated_at'] ?? '',
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

class CancellationResult {
  final String bookingId;
  final String oldStatus;
  final String newStatus;
  final double cancellationFee;
  final String cancelledAt;

  CancellationResult({
    required this.bookingId,
    required this.oldStatus,
    required this.newStatus,
    required this.cancellationFee,
    required this.cancelledAt,
  });

  factory CancellationResult.fromJson(Map<String, dynamic> json) {
    return CancellationResult(
      bookingId: json['booking_id'] ?? '',
      oldStatus: json['old_status'] ?? '',
      newStatus: json['new_status'] ?? '',
      cancellationFee: (json['cancellation_fee'] ?? 0).toDouble(),
      cancelledAt: json['cancelled_at'] ?? '',
    );
  }
}

// ==================== RIVERPOD PROVIDERS ====================

/// Provider for RideBookingService
final rideBookingServiceProvider = Provider<RideBookingService>((ref) {
  return RideBookingService(ref.watch(supabaseClientProvider));
});

/// Provider for active booking
final activeBookingProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(rideBookingServiceProvider);
  return await service.getActiveBooking();
});

/// Provider for ride types
final rideTypesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(rideBookingServiceProvider);
  return await service.getRideTypes();
});

/// Stream provider for watching a specific booking
final bookingStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, bookingId) {
  final service = ref.watch(rideBookingServiceProvider);
  return service.watchBooking(bookingId);
});
