import 'package:latlong2/latlong.dart';

/// ============================================================
/// ENTERPRISE DRIVER RETURN SYSTEM - CORE MODELS
/// ============================================================
/// Supports 3 return models:
/// - Model 1: Round Trip (Default) - Driver returns car
/// - Model 2: Platform-Assisted Return - Platform handles driver return
/// - Model 3: Zone-Based Pooling - Driver gets next job nearby

// ==================== RETURN MODEL TYPES ====================

/// The three driver return models
enum ReturnModel {
  /// Model 1: Driver drives car back to pickup location
  /// - Default for all trips
  /// - Mandatory for hourly, first-time users, low-density zones
  roundTrip,

  /// Model 2: Trip ends at destination, platform arranges driver return
  /// - Optional, requires driver opt-in
  /// - Customer pays return fee
  platformReturn,

  /// Model 3: Driver may get next job nearby, no forced return
  /// - System-controlled, not user-selectable
  /// - Only in high-density areas during peak hours
  zoneBased,
}

// ==================== TRIP PHASES ====================

/// Trip phases for live tracking UI
enum TripPhase {
  // Pre-trip
  searchingDriver,
  driverAssigned,
  driverEnRoute,
  driverArrived,

  // Active trip - Customer journey
  tripStarted,
  toDestination,
  arrivedAtDestination,

  // Return phases - Model 1
  returnJourneyStarted,
  returnInProgress,
  arrivedAtPickup,

  // Platform return - Model 2
  carHandedOver,
  driverReturnArranged,

  // Zone pooling - Model 3
  waitingNextJob,
  nextJobAssigned,

  // Complete
  tripCompleted,
  tripCancelled,
}

// ==================== DISPLAY HELPERS ====================

extension TripPhaseExtension on TripPhase {
  String get displayName {
    switch (this) {
      case TripPhase.searchingDriver:
        return 'Finding your driver...';
      case TripPhase.driverAssigned:
        return 'Driver assigned';
      case TripPhase.driverEnRoute:
        return 'Driver on the way';
      case TripPhase.driverArrived:
        return 'Driver arrived';
      case TripPhase.tripStarted:
        return 'Trip started';
      case TripPhase.toDestination:
        return 'Driving to destination';
      case TripPhase.arrivedAtDestination:
        return 'Arrived at destination';
      case TripPhase.returnJourneyStarted:
        return 'Return journey started';
      case TripPhase.returnInProgress:
        return 'Returning your car';
      case TripPhase.arrivedAtPickup:
        return 'Car returned safely';
      case TripPhase.carHandedOver:
        return 'Car handed over';
      case TripPhase.driverReturnArranged:
        return 'Driver return arranged';
      case TripPhase.waitingNextJob:
        return 'Optimizing driver availability';
      case TripPhase.nextJobAssigned:
        return 'Driver assigned to next trip';
      case TripPhase.tripCompleted:
        return 'Trip completed';
      case TripPhase.tripCancelled:
        return 'Trip cancelled';
    }
  }

  bool get isReturnPhase {
    return this == TripPhase.returnJourneyStarted ||
        this == TripPhase.returnInProgress ||
        this == TripPhase.arrivedAtPickup;
  }

  bool get isCompleted {
    return this == TripPhase.tripCompleted;
  }

  bool get canEndTrip {
    // For Model 1, trip can only end after return is complete
    return this == TripPhase.arrivedAtPickup ||
        this == TripPhase.carHandedOver ||
        this == TripPhase.nextJobAssigned ||
        this == TripPhase.tripCompleted;
  }
}

extension ReturnModelExtension on ReturnModel {
  String get displayName {
    switch (this) {
      case ReturnModel.roundTrip:
        return 'Round Trip';
      case ReturnModel.platformReturn:
        return 'End at Destination';
      case ReturnModel.zoneBased:
        return 'Optimized Pricing';
    }
  }

  String get description {
    switch (this) {
      case ReturnModel.roundTrip:
        return 'Driver will return your car safely to pickup location';
      case ReturnModel.platformReturn:
        return 'Trip ends at destination. Drivo handles driver return.';
      case ReturnModel.zoneBased:
        return 'Local driver availability optimized for faster service';
    }
  }

  String get shortLabel {
    switch (this) {
      case ReturnModel.roundTrip:
        return 'Recommended';
      case ReturnModel.platformReturn:
        return '+ Return Fee';
      case ReturnModel.zoneBased:
        return 'Smart Pricing';
    }
  }

  bool get isDefault => this == ReturnModel.roundTrip;
}

// ==================== RETURN POLICY ====================

/// City-configurable return policy for each model
class ReturnPolicy {
  final ReturnModel model;
  final bool isAvailable;
  final bool isMandatory;
  final double? additionalFee;
  final String? unavailableReason;
  final List<String> eligibleServiceTypes;
  final bool requiresDriverOptIn;

  const ReturnPolicy({
    required this.model,
    required this.isAvailable,
    this.isMandatory = false,
    this.additionalFee,
    this.unavailableReason,
    this.eligibleServiceTypes = const ['Hourly', 'Half Day', 'Full Day'],
    this.requiresDriverOptIn = false,
  });

  ReturnPolicy copyWith({
    ReturnModel? model,
    bool? isAvailable,
    bool? isMandatory,
    double? additionalFee,
    String? unavailableReason,
    List<String>? eligibleServiceTypes,
    bool? requiresDriverOptIn,
  }) {
    return ReturnPolicy(
      model: model ?? this.model,
      isAvailable: isAvailable ?? this.isAvailable,
      isMandatory: isMandatory ?? this.isMandatory,
      additionalFee: additionalFee ?? this.additionalFee,
      unavailableReason: unavailableReason ?? this.unavailableReason,
      eligibleServiceTypes: eligibleServiceTypes ?? this.eligibleServiceTypes,
      requiresDriverOptIn: requiresDriverOptIn ?? this.requiresDriverOptIn,
    );
  }
}

// ==================== SERVICE ZONE ====================

/// Zone definition for Model 3 (Zone-Based Pooling)
class ServiceZone {
  final String id;
  final String name;
  final String cityCode;
  final List<LatLng> boundary;
  final List<String> adjacentZoneIds;
  final bool poolingEnabled;
  final int maxIdleMinutes;
  final double poolingDiscount; // Percentage discount when pooling applies

  const ServiceZone({
    required this.id,
    required this.name,
    required this.cityCode,
    required this.boundary,
    this.adjacentZoneIds = const [],
    this.poolingEnabled = false,
    this.maxIdleMinutes = 15,
    this.poolingDiscount = 0.10, // 10% default
  });

  bool containsPoint(LatLng point) {
    // Ray casting algorithm for point-in-polygon
    int crossings = 0;
    for (int i = 0; i < boundary.length; i++) {
      final j = (i + 1) % boundary.length;
      if ((boundary[i].latitude <= point.latitude &&
              point.latitude < boundary[j].latitude) ||
          (boundary[j].latitude <= point.latitude &&
              point.latitude < boundary[i].latitude)) {
        final slope = (boundary[j].longitude - boundary[i].longitude) /
            (boundary[j].latitude - boundary[i].latitude);
        final xIntersect = boundary[i].longitude +
            slope * (point.latitude - boundary[i].latitude);
        if (point.longitude < xIntersect) {
          crossings++;
        }
      }
    }
    return crossings % 2 == 1;
  }
}

// ==================== RETURN TASK ====================

/// Return task for Model 2 (Platform-Assisted Return)
enum ReturnTaskStatus {
  pending,
  cabBooked,
  driverPickedUp,
  completed,
  failed,
}

class ReturnTask {
  final String id;
  final String bookingId;
  final String driverId;
  final LatLng fromLocation;
  final String fromAddress;
  final ReturnTaskStatus status;
  final String? cabBookingId;
  final double? reimbursementAmount;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ReturnTask({
    required this.id,
    required this.bookingId,
    required this.driverId,
    required this.fromLocation,
    required this.fromAddress,
    this.status = ReturnTaskStatus.pending,
    this.cabBookingId,
    this.reimbursementAmount,
    required this.createdAt,
    this.completedAt,
  });

  ReturnTask copyWith({
    String? id,
    String? bookingId,
    String? driverId,
    LatLng? fromLocation,
    String? fromAddress,
    ReturnTaskStatus? status,
    String? cabBookingId,
    double? reimbursementAmount,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ReturnTask(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      driverId: driverId ?? this.driverId,
      fromLocation: fromLocation ?? this.fromLocation,
      fromAddress: fromAddress ?? this.fromAddress,
      status: status ?? this.status,
      cabBookingId: cabBookingId ?? this.cabBookingId,
      reimbursementAmount: reimbursementAmount ?? this.reimbursementAmount,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

// ==================== TRIP RETURN INFO ====================

/// Embedded in Booking to track return details
class TripReturnInfo {
  final ReturnModel model;
  final TripPhase currentPhase;
  final double? returnFee;
  final DateTime? returnStartedAt;
  final DateTime? returnCompletedAt;
  final LatLng? returnDestination;
  final String? returnTaskId; // For Model 2
  final String? nextJobId; // For Model 3
  final bool isReturnComplete;

  const TripReturnInfo({
    required this.model,
    this.currentPhase = TripPhase.tripStarted,
    this.returnFee,
    this.returnStartedAt,
    this.returnCompletedAt,
    this.returnDestination,
    this.returnTaskId,
    this.nextJobId,
    this.isReturnComplete = false,
  });

  TripReturnInfo copyWith({
    ReturnModel? model,
    TripPhase? currentPhase,
    double? returnFee,
    DateTime? returnStartedAt,
    DateTime? returnCompletedAt,
    LatLng? returnDestination,
    String? returnTaskId,
    String? nextJobId,
    bool? isReturnComplete,
  }) {
    return TripReturnInfo(
      model: model ?? this.model,
      currentPhase: currentPhase ?? this.currentPhase,
      returnFee: returnFee ?? this.returnFee,
      returnStartedAt: returnStartedAt ?? this.returnStartedAt,
      returnCompletedAt: returnCompletedAt ?? this.returnCompletedAt,
      returnDestination: returnDestination ?? this.returnDestination,
      returnTaskId: returnTaskId ?? this.returnTaskId,
      nextJobId: nextJobId ?? this.nextJobId,
      isReturnComplete: isReturnComplete ?? this.isReturnComplete,
    );
  }

  /// Calculate total return time in minutes
  int? get returnDurationMinutes {
    if (returnStartedAt == null || returnCompletedAt == null) return null;
    return returnCompletedAt!.difference(returnStartedAt!).inMinutes;
  }
}
