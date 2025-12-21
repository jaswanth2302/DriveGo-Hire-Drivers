import 'return_models.dart';

// Driver Model
class Driver {
  final String id;
  final String name;
  final String photoUrl;
  final double rating;
  final String carModel;
  final String plateNumber;
  final bool acceptsPlatformReturn; // For Model 2 opt-in

  Driver({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.carModel,
    required this.plateNumber,
    this.acceptsPlatformReturn = true,
  });
}

// Booking Model
enum BookingStatus {
  searching,
  confirmed,
  arrived,
  inProgress,
  returning, // New: Return journey in progress
  completed,
  cancelled
}

class Booking {
  final String id;
  final String customerId;
  final String? driverId;
  final BookingStatus status;
  final double price;
  final String serviceType; // Hourly, Half-Day, etc.

  // Return system fields
  final ReturnModel returnModel;
  final TripReturnInfo? returnInfo;
  final String? zoneId;

  Booking({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.status,
    required this.price,
    required this.serviceType,
    this.returnModel = ReturnModel.roundTrip,
    this.returnInfo,
    this.zoneId,
  });

  Booking copyWith({
    BookingStatus? status,
    String? driverId,
    ReturnModel? returnModel,
    TripReturnInfo? returnInfo,
    String? zoneId,
  }) {
    return Booking(
      id: id,
      customerId: customerId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      price: price,
      serviceType: serviceType,
      returnModel: returnModel ?? this.returnModel,
      returnInfo: returnInfo ?? this.returnInfo,
      zoneId: zoneId ?? this.zoneId,
    );
  }

  /// Total price including return fee
  double get totalPrice {
    final returnFee = returnInfo?.returnFee ?? 0;
    return price + returnFee;
  }

  /// Check if trip can be ended based on return model
  bool get canEndTrip {
    if (returnModel == ReturnModel.roundTrip) {
      // Model 1: Can only end after car is returned
      return returnInfo?.currentPhase.canEndTrip ?? false;
    }
    return true;
  }

  /// Check if return is in progress
  bool get isReturning {
    return status == BookingStatus.returning ||
        (returnInfo?.currentPhase.isReturnPhase ?? false);
  }
}

// Multi-stop booking models
enum StopType { pickup, stop, destination }

enum LegType { outward, returnTrip }

/// Represents a single stop in the trip
class TripStop {
  final String id;
  final String address;
  final double latitude;
  final double longitude;
  final StopType type;

  TripStop({
    required this.id,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  TripStop copyWith({
    String? id,
    String? address,
    double? latitude,
    double? longitude,
    StopType? type,
  }) {
    return TripStop(
      id: id ?? this.id,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
    );
  }
}

/// Represents one leg of the journey (outward or return)
class TripLeg {
  final LegType type;
  final List<TripStop> stops;

  TripLeg({
    required this.type,
    required this.stops,
  });

  TripLeg copyWith({
    LegType? type,
    List<TripStop>? stops,
  }) {
    return TripLeg(
      type: type ?? this.type,
      stops: stops ?? List.from(this.stops),
    );
  }

  /// Add a stop at a specific index
  TripLeg addStopAt(int index, TripStop stop) {
    final newStops = List<TripStop>.from(stops);
    newStops.insert(index, stop);
    return copyWith(stops: newStops);
  }

  /// Remove a stop by id
  TripLeg removeStop(String stopId) {
    final newStops = stops.where((s) => s.id != stopId).toList();
    return copyWith(stops: newStops);
  }

  /// Update a stop
  TripLeg updateStop(String stopId, TripStop updatedStop) {
    final newStops =
        stops.map((s) => s.id == stopId ? updatedStop : s).toList();
    return copyWith(stops: newStops);
  }
}
