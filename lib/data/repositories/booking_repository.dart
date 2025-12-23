import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Repository for booking-related database operations
class BookingRepository {
  final SupabaseClient _client;

  BookingRepository(this._client);

  // ==================== BOOKINGS ====================

  /// Create a new booking
  Future<Map<String, dynamic>> createBooking({
    required String customerId,
    required String serviceType,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
    String? carTypeId,
    String? transmission,
    String timingMode = 'now',
    DateTime? scheduledTime,
    String returnModel = 'round_trip',
    String tripType = 'round_trip',
    double? estimatedDrivingHours,
    double? declaredWaitingHours,
    double? hourlyRate,
    double? estimatedTotal,
    String paymentMethod = 'cash',
  }) async {
    final response = await _client.bookings
        .insert({
          'customer_id': customerId,
          'service_type': serviceType,
          'pickup_address': pickupAddress,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'destination_address': destinationAddress,
          'destination_lat': destinationLat,
          'destination_lng': destinationLng,
          'car_type_id': carTypeId,
          'transmission': transmission,
          'timing_mode': timingMode,
          'scheduled_time': scheduledTime?.toIso8601String(),
          'return_model': returnModel,
          'trip_type': tripType,
          'estimated_driving_hours': estimatedDrivingHours ?? 2,
          'declared_waiting_hours': declaredWaitingHours ?? 0,
          'hourly_rate': hourlyRate ?? 199,
          'estimated_total': estimatedTotal,
          'payment_method': paymentMethod,
          'status': 'searching',
        })
        .select()
        .single();

    // Create live billing record
    await _client.liveBilling.insert({
      'booking_id': response['id'],
      'state': 'not_started',
      'declared_waiting_minutes': ((declaredWaitingHours ?? 0) * 60).toInt(),
    });

    // Create trip return info
    await _client.tripReturnInfo.insert({
      'booking_id': response['id'],
      'model': returnModel,
      'current_phase': 'searching_driver',
    });

    return response;
  }

  /// Get booking by ID
  Future<Map<String, dynamic>?> getBooking(String bookingId) async {
    return await _client.bookings
        .select(
            '*, drivers(*), car_types(*), live_billing(*), trip_return_info(*)')
        .eq('id', bookingId)
        .maybeSingle();
  }

  /// Get user's bookings
  Future<List<Map<String, dynamic>>> getUserBookings(String userId,
      {int limit = 20}) async {
    final response = await _client.bookings
        .select('*, drivers(*), car_types(*)')
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get driver's bookings
  Future<List<Map<String, dynamic>>> getDriverBookings(String driverId,
      {int limit = 20}) async {
    final response = await _client.bookings
        .select('*, users(*), car_types(*)')
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Set timestamp based on status
    switch (status) {
      case 'confirmed':
        updates['confirmed_at'] = DateTime.now().toIso8601String();
        break;
      case 'arrived':
        updates['driver_arrived_at'] = DateTime.now().toIso8601String();
        break;
      case 'in_progress':
        updates['trip_started_at'] = DateTime.now().toIso8601String();
        break;
      case 'completed':
        updates['trip_ended_at'] = DateTime.now().toIso8601String();
        break;
      case 'cancelled':
        updates['cancelled_at'] = DateTime.now().toIso8601String();
        break;
    }

    await _client.bookings.update(updates).eq('id', bookingId);
  }

  /// Assign driver to booking
  Future<void> assignDriver(String bookingId, String driverId) async {
    await _client.bookings.update({
      'driver_id': driverId,
      'status': 'confirmed',
      'confirmed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);

    // Update trip phase
    await _client.tripReturnInfo.update({
      'current_phase': 'driver_assigned',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('booking_id', bookingId);
  }

  /// Cancel booking
  Future<void> cancelBooking(String bookingId, String reason) async {
    await _client.bookings.update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
      'cancellation_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);

    // Update trip phase
    await _client.tripReturnInfo.update({
      'current_phase': 'trip_cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('booking_id', bookingId);
  }

  // ==================== TRIP STOPS ====================

  /// Add trip stop
  Future<Map<String, dynamic>> addTripStop({
    required String bookingId,
    required String legType,
    required String stopType,
    required int sequenceOrder,
    required String address,
    required double lat,
    required double lng,
  }) async {
    return await _client.tripStops
        .insert({
          'booking_id': bookingId,
          'leg_type': legType,
          'stop_type': stopType,
          'sequence_order': sequenceOrder,
          'address': address,
          'lat': lat,
          'lng': lng,
        })
        .select()
        .single();
  }

  /// Get trip stops for booking
  Future<List<Map<String, dynamic>>> getTripStops(String bookingId) async {
    final response = await _client.tripStops
        .select()
        .eq('booking_id', bookingId)
        .order('sequence_order');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Mark stop as arrived
  Future<void> markStopArrived(String stopId) async {
    await _client.tripStops.update({
      'arrived_at': DateTime.now().toIso8601String(),
    }).eq('id', stopId);
  }

  /// Mark stop as departed
  Future<void> markStopDeparted(String stopId) async {
    await _client.tripStops.update({
      'departed_at': DateTime.now().toIso8601String(),
    }).eq('id', stopId);
  }

  // ==================== LIVE BILLING ====================

  /// Update billing state
  Future<void> updateBillingState(String bookingId, String state) async {
    final updates = <String, dynamic>{
      'state': state,
      'updated_at': DateTime.now().toIso8601String(),
    };

    switch (state) {
      case 'driving':
        updates['trip_start_time'] = DateTime.now().toIso8601String();
        break;
      case 'waiting':
        updates['waiting_start_time'] = DateTime.now().toIso8601String();
        break;
      case 'over_waiting':
        updates['over_wait_start_time'] = DateTime.now().toIso8601String();
        break;
      case 'returning':
        updates['return_start_time'] = DateTime.now().toIso8601String();
        break;
      case 'completed':
        updates['trip_end_time'] = DateTime.now().toIso8601String();
        break;
    }

    await _client.liveBilling.update(updates).eq('booking_id', bookingId);
  }

  /// Update fare breakdown
  Future<void> updateFareBreakdown(
    String bookingId, {
    double? drivingCharge,
    double? waitingCharge,
    double? overWaitCharge,
    double? returnFee,
    double? totalFare,
    double? driverEarnings,
    double? platformMargin,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (drivingCharge != null) updates['driving_charge'] = drivingCharge;
    if (waitingCharge != null) updates['waiting_charge'] = waitingCharge;
    if (overWaitCharge != null) updates['over_wait_charge'] = overWaitCharge;
    if (returnFee != null) updates['return_fee'] = returnFee;
    if (totalFare != null) updates['total_fare'] = totalFare;
    if (driverEarnings != null)
      updates['driver_total_earnings'] = driverEarnings;
    if (platformMargin != null) updates['platform_margin'] = platformMargin;

    await _client.liveBilling.update(updates).eq('booking_id', bookingId);
  }

  // ==================== TRIP RETURN INFO ====================

  /// Update trip phase
  Future<void> updateTripPhase(String bookingId, String phase) async {
    await _client.tripReturnInfo.update({
      'current_phase': phase,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('booking_id', bookingId);
  }

  /// Start return journey
  Future<void> startReturnJourney(String bookingId) async {
    await _client.tripReturnInfo.update({
      'current_phase': 'return_journey_started',
      'return_started_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('booking_id', bookingId);

    // Update booking status
    await _client.bookings.update({
      'status': 'returning',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Complete return journey
  Future<void> completeReturnJourney(String bookingId) async {
    await _client.tripReturnInfo.update({
      'current_phase': 'trip_completed',
      'return_completed_at': DateTime.now().toIso8601String(),
      'is_return_complete': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('booking_id', bookingId);

    // Update booking status
    await _client.bookings.update({
      'status': 'completed',
      'trip_ended_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  // ==================== RATINGS ====================

  /// Submit rating
  Future<void> submitRating({
    required String bookingId,
    required String userId,
    required String driverId,
    required int rating,
    String? feedback,
    List<String>? feedbackTags,
  }) async {
    await _client.ratings.insert({
      'booking_id': bookingId,
      'user_id': userId,
      'driver_id': driverId,
      'rating': rating,
      'feedback': feedback,
      'feedback_tags': feedbackTags,
    });
  }
}

// Riverpod provider
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(supabaseClientProvider));
});
