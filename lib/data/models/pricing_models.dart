/// Enterprise Pricing & Billing System for Drivo
/// Production-ready time-based pricing (NOT per-km)

/// Pricing Constants
class DrivoPricing {
  // Customer-facing rates
  static const double drivingRatePerHour = 199.0;
  static const double waitingRatePerHour = 99.0;
  static const double overWaitPenaltyPerHour = 149.0;

  // Driver payout rates (internal)
  static const double driverDrivingRatePerHour = 140.0;
  static const double driverWaitingRatePerHour = 100.0;

  // Constraints
  static const int minimumBookingHours = 2;
  static const int maximumWaitingHours = 3;
  static const int overWaitIncrementMinutes = 15;

  // Return fee rate (per km)
  static const double returnFeePerKm = 15.0;
}

/// Represents a customer's fare breakdown
class FareBreakdown {
  final double drivingHours;
  final double waitingHours;
  final double overWaitHours;
  final double returnDistanceKm;
  final bool hasReturnFee;

  FareBreakdown({
    required this.drivingHours,
    this.waitingHours = 0,
    this.overWaitHours = 0,
    this.returnDistanceKm = 0,
    this.hasReturnFee = false,
  });

  // Customer charges
  double get drivingCharge => drivingHours * DrivoPricing.drivingRatePerHour;
  double get waitingCharge => waitingHours * DrivoPricing.waitingRatePerHour;
  double get overWaitCharge =>
      overWaitHours * DrivoPricing.overWaitPenaltyPerHour;
  double get returnFee =>
      hasReturnFee ? returnDistanceKm * DrivoPricing.returnFeePerKm : 0;

  double get subtotal => drivingCharge + waitingCharge + overWaitCharge;
  double get totalFare => subtotal + returnFee;

  // Driver earnings (internal)
  double get driverDrivingEarnings =>
      drivingHours * DrivoPricing.driverDrivingRatePerHour;
  double get driverWaitingEarnings =>
      (waitingHours + overWaitHours) * DrivoPricing.driverWaitingRatePerHour;
  double get driverTotalEarnings =>
      driverDrivingEarnings + driverWaitingEarnings;

  // Platform margin
  double get platformMargin => totalFare - driverTotalEarnings;

  /// Create estimate from hours
  factory FareBreakdown.estimate({
    required double drivingHours,
    double waitingHours = 0,
    double returnDistanceKm = 0,
    bool hasReturnFee = false,
  }) {
    // Enforce minimum booking
    final adjustedDriving = drivingHours < DrivoPricing.minimumBookingHours
        ? DrivoPricing.minimumBookingHours.toDouble()
        : drivingHours;

    return FareBreakdown(
      drivingHours: adjustedDriving,
      waitingHours:
          waitingHours.clamp(0, DrivoPricing.maximumWaitingHours.toDouble()),
      returnDistanceKm: returnDistanceKm,
      hasReturnFee: hasReturnFee,
    );
  }

  /// Generate invoice line items
  List<InvoiceLineItem> toLineItems() {
    final items = <InvoiceLineItem>[];

    items.add(InvoiceLineItem(
      description: 'Driving Time',
      detail:
          '${drivingHours.toStringAsFixed(1)} hrs × ₹${DrivoPricing.drivingRatePerHour.toInt()}/hr',
      amount: drivingCharge,
    ));

    if (waitingHours > 0) {
      items.add(InvoiceLineItem(
        description: 'Waiting Time',
        detail:
            '${waitingHours.toStringAsFixed(1)} hrs × ₹${DrivoPricing.waitingRatePerHour.toInt()}/hr',
        amount: waitingCharge,
      ));
    }

    if (overWaitHours > 0) {
      items.add(InvoiceLineItem(
        description: 'Extended Waiting',
        detail:
            '${overWaitHours.toStringAsFixed(1)} hrs × ₹${DrivoPricing.overWaitPenaltyPerHour.toInt()}/hr',
        amount: overWaitCharge,
        isWarning: true,
      ));
    }

    if (returnFee > 0) {
      items.add(InvoiceLineItem(
        description: 'Driver Return Fee',
        detail:
            '${returnDistanceKm.toStringAsFixed(1)} km × ₹${DrivoPricing.returnFeePerKm.toInt()}/km',
        amount: returnFee,
      ));
    }

    return items;
  }
}

/// Single line item in an invoice
class InvoiceLineItem {
  final String description;
  final String detail;
  final double amount;
  final bool isWarning;

  InvoiceLineItem({
    required this.description,
    required this.detail,
    required this.amount,
    this.isWarning = false,
  });
}

/// Trip billing state for live tracking
enum BillingState {
  notStarted,
  driving,
  waiting,
  overWaiting,
  returning,
  completed,
}

/// Live billing tracker
class LiveBillingTracker {
  BillingState state = BillingState.notStarted;
  DateTime? tripStartTime;
  DateTime? waitingStartTime;
  DateTime? overWaitStartTime;
  DateTime? returnStartTime;
  DateTime? tripEndTime;

  final int declaredWaitingMinutes;

  LiveBillingTracker({required this.declaredWaitingMinutes});

  void startTrip() {
    tripStartTime = DateTime.now();
    state = BillingState.driving;
  }

  void startWaiting() {
    waitingStartTime = DateTime.now();
    state = BillingState.waiting;
  }

  void startOverWait() {
    overWaitStartTime = DateTime.now();
    state = BillingState.overWaiting;
  }

  void startReturn() {
    returnStartTime = DateTime.now();
    state = BillingState.returning;
  }

  void endTrip() {
    tripEndTime = DateTime.now();
    state = BillingState.completed;
  }

  /// Check if over waiting threshold
  bool get isOverWaiting {
    if (waitingStartTime == null) return false;
    final waitedMinutes =
        DateTime.now().difference(waitingStartTime!).inMinutes;
    return waitedMinutes > declaredWaitingMinutes;
  }

  /// Get current driving duration in hours
  double get currentDrivingHours {
    if (tripStartTime == null) return 0;
    final endTime =
        waitingStartTime ?? returnStartTime ?? tripEndTime ?? DateTime.now();
    return endTime.difference(tripStartTime!).inMinutes / 60;
  }

  /// Get current waiting duration in hours
  double get currentWaitingHours {
    if (waitingStartTime == null) return 0;
    final declaredHours = declaredWaitingMinutes / 60;
    final actualMinutes = (returnStartTime ?? tripEndTime ?? DateTime.now())
        .difference(waitingStartTime!)
        .inMinutes;
    return (actualMinutes / 60).clamp(0, declaredHours);
  }

  /// Get over-wait duration in hours
  double get overWaitHours {
    if (waitingStartTime == null) return 0;
    final declaredHours = declaredWaitingMinutes / 60;
    final actualMinutes = (returnStartTime ?? tripEndTime ?? DateTime.now())
        .difference(waitingStartTime!)
        .inMinutes;
    final actualHours = actualMinutes / 60;
    return actualHours > declaredHours ? actualHours - declaredHours : 0;
  }

  /// Generate current fare breakdown
  FareBreakdown getCurrentFare(
      {double returnDistanceKm = 0, bool hasReturnFee = false}) {
    return FareBreakdown(
      drivingHours: currentDrivingHours,
      waitingHours: currentWaitingHours,
      overWaitHours: overWaitHours,
      returnDistanceKm: returnDistanceKm,
      hasReturnFee: hasReturnFee,
    );
  }
}
