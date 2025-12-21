import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/return_models.dart';

/// ============================================================
/// RETURN SERVICE - Enterprise Driver Return System
/// ============================================================
/// Handles return model availability, pricing, and validation

class ReturnService {
  // City-specific return fees (configurable per city)
  static const Map<String, double> _cityReturnFees = {
    'BLR': 200.0, // Bangalore
    'MUM': 250.0, // Mumbai
    'DEL': 200.0, // Delhi
    'CHN': 180.0, // Chennai
    'HYD': 180.0, // Hyderabad
    'default': 200.0,
  };

  // Default zone pooling discount
  static const double _defaultPoolingDiscount = 0.10; // 10%

  /// Get available return models for a trip
  Future<List<ReturnPolicy>> getAvailableModels({
    required LatLng pickup,
    required LatLng destination,
    required String serviceType,
    required bool isFirstTimeUser,
    String cityCode = 'BLR',
  }) async {
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 300));

    final returnFee = _cityReturnFees[cityCode] ?? _cityReturnFees['default']!;

    // Model 1: Round Trip - Always available, mandatory for certain cases
    final roundTripMandatory = _isRoundTripMandatory(
      serviceType: serviceType,
      isFirstTimeUser: isFirstTimeUser,
    );

    final policies = <ReturnPolicy>[
      // Model 1: Round Trip (Always available)
      ReturnPolicy(
        model: ReturnModel.roundTrip,
        isAvailable: true,
        isMandatory: roundTripMandatory,
        additionalFee: null, // Included in time-based billing
        eligibleServiceTypes: const ['Hourly', 'Half Day', 'Full Day'],
      ),

      // Model 2: Platform-Assisted Return
      ReturnPolicy(
        model: ReturnModel.platformReturn,
        isAvailable: !roundTripMandatory,
        isMandatory: false,
        additionalFee: returnFee,
        requiresDriverOptIn: true,
        unavailableReason: roundTripMandatory
            ? 'Round trip is required for this booking type'
            : null,
        eligibleServiceTypes: const ['Half Day', 'Full Day'],
      ),

      // Model 3: Zone-Based Pooling (System controlled)
      // Not shown to users directly, but affects pricing
      ReturnPolicy(
        model: ReturnModel.zoneBased,
        isAvailable: false, // Only enabled by system
        isMandatory: false,
        additionalFee: null,
        unavailableReason: 'Zone-based optimization is system-managed',
        eligibleServiceTypes: const ['Hourly'],
      ),
    ];

    return policies;
  }

  /// Check if round trip is mandatory
  bool _isRoundTripMandatory({
    required String serviceType,
    required bool isFirstTimeUser,
  }) {
    // Mandatory for:
    // 1. Hourly bookings
    // 2. First-time users
    if (serviceType == 'Hourly') return true;
    if (isFirstTimeUser) return true;
    return false;
  }

  /// Calculate return fee for Model 2
  Future<double> calculateReturnFee({
    required LatLng dropLocation,
    String cityCode = 'BLR',
  }) async {
    // For MVP: Fixed fee per city
    // Future: Could be distance-based
    return _cityReturnFees[cityCode] ?? _cityReturnFees['default']!;
  }

  /// Calculate estimated total price with return model
  Future<Map<String, double>> calculatePricing({
    required double baseFare,
    required double estimatedDuration, // in hours
    required double hourlyRate,
    required ReturnModel returnModel,
    required double estimatedReturnDuration, // in hours
    String cityCode = 'BLR',
  }) async {
    double tripCost = baseFare + (hourlyRate * estimatedDuration);
    double returnCost = 0;
    double discount = 0;

    switch (returnModel) {
      case ReturnModel.roundTrip:
        // Include return time in total billing
        returnCost = hourlyRate * estimatedReturnDuration;
        break;

      case ReturnModel.platformReturn:
        // Fixed return fee
        returnCost = _cityReturnFees[cityCode] ?? _cityReturnFees['default']!;
        break;

      case ReturnModel.zoneBased:
        // Apply pooling discount
        discount = tripCost * _defaultPoolingDiscount;
        break;
    }

    return {
      'baseFare': baseFare,
      'tripCost': tripCost,
      'returnCost': returnCost,
      'discount': discount,
      'total': tripCost + returnCost - discount,
      'estimatedDuration': estimatedDuration +
          (returnModel == ReturnModel.roundTrip ? estimatedReturnDuration : 0),
    };
  }

  /// Check if zone pooling is available for a location
  Future<bool> isZonePoolingAvailable({
    required LatLng location,
    required DateTime tripTime,
  }) async {
    // For MVP: Disabled
    // Future: Check if location is in high-density zone during peak hours
    return false;
  }

  /// Validate geo-fence for return completion
  Future<GeoFenceResult> validateReturnLocation({
    required LatLng currentLocation,
    required LatLng expectedLocation,
    double radiusMeters = 100,
  }) async {
    const Distance distance = Distance();
    final meters = distance.as(
      LengthUnit.Meter,
      currentLocation,
      expectedLocation,
    );

    if (meters <= radiusMeters) {
      return GeoFenceResult(
        isWithinRadius: true,
        distanceMeters: meters,
        message: 'Location verified',
      );
    } else if (meters <= radiusMeters * 5) {
      return GeoFenceResult(
        isWithinRadius: false,
        distanceMeters: meters,
        message:
            'Please move closer to the pickup location (${meters.toInt()}m away)',
      );
    } else {
      return GeoFenceResult(
        isWithinRadius: false,
        distanceMeters: meters,
        message: 'You are too far from the expected location',
        requiresAlert: true,
      );
    }
  }

  /// Create return task for Model 2
  Future<ReturnTask> createReturnTask({
    required String bookingId,
    required String driverId,
    required LatLng fromLocation,
    required String fromAddress,
  }) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 500));

    return ReturnTask(
      id: 'RT_${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      driverId: driverId,
      fromLocation: fromLocation,
      fromAddress: fromAddress,
      status: ReturnTaskStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  /// Get return time estimate
  Future<Duration> getReturnTimeEstimate({
    required LatLng fromLocation,
    required LatLng toLocation,
  }) async {
    const Distance distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, fromLocation, toLocation);

    // Estimate: 3 minutes per km in city traffic
    final minutes = (km * 3).ceil();
    return Duration(minutes: minutes.clamp(5, 120));
  }
}

/// Result of geo-fence validation
class GeoFenceResult {
  final bool isWithinRadius;
  final double distanceMeters;
  final String message;
  final bool requiresAlert;

  GeoFenceResult({
    required this.isWithinRadius,
    required this.distanceMeters,
    required this.message,
    this.requiresAlert = false,
  });
}

/// Provider for ReturnService
final returnServiceProvider = Provider<ReturnService>((ref) {
  return ReturnService();
});

/// Provider for available return policies
final availableReturnPoliciesProvider =
    FutureProvider.family<List<ReturnPolicy>, ReturnPolicyRequest>(
        (ref, request) async {
  final service = ref.read(returnServiceProvider);
  return service.getAvailableModels(
    pickup: request.pickup,
    destination: request.destination,
    serviceType: request.serviceType,
    isFirstTimeUser: request.isFirstTimeUser,
    cityCode: request.cityCode,
  );
});

/// Request object for return policies
class ReturnPolicyRequest {
  final LatLng pickup;
  final LatLng destination;
  final String serviceType;
  final bool isFirstTimeUser;
  final String cityCode;

  ReturnPolicyRequest({
    required this.pickup,
    required this.destination,
    required this.serviceType,
    this.isFirstTimeUser = false,
    this.cityCode = 'BLR',
  });
}
