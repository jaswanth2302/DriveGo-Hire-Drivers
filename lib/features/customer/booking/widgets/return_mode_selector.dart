import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/return_models.dart';

/// Rapido-Style Return Mode Selector
/// Dark headers, yellow accents, clean selection cards
class ReturnModeSelector extends StatelessWidget {
  final String tripType;
  final LatLng? outwardPickup;
  final LatLng? outwardDestination;
  final LatLng? returnPickup;
  final LatLng? returnDestination;
  final ReturnModel selectedModel;
  final ValueChanged<ReturnModel> onModelSelected;
  final double? estimatedReturnDuration;
  final double? calculatedReturnFee;

  const ReturnModeSelector({
    super.key,
    required this.tripType,
    this.outwardPickup,
    this.outwardDestination,
    this.returnPickup,
    this.returnDestination,
    required this.selectedModel,
    required this.onModelSelected,
    this.estimatedReturnDuration,
    this.calculatedReturnFee,
  });

  bool get _isReturnToSameLocation {
    if (outwardPickup == null || returnDestination == null) return true;
    const Distance distance = Distance();
    final meters =
        distance.as(LengthUnit.Meter, outwardPickup!, returnDestination!);
    return meters < 100;
  }

  double get _returnDistanceKm {
    if (outwardPickup == null || outwardDestination == null) return 0;
    const Distance distance = Distance();
    return distance.as(
        LengthUnit.Kilometer, outwardPickup!, outwardDestination!);
  }

  @override
  Widget build(BuildContext context) {
    final returnFee = calculatedReturnFee ?? (_returnDistanceKm * 15);
    final isRoundTrip = tripType == 'round_trip';
    final hasReturnFee = !_isReturnToSameLocation && returnFee > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rapido-style header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          color: Colors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver Return',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isRoundTrip
                    ? 'Your car will be returned to pickup'
                    : 'We\'ll arrange driver\'s return',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Content area
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Trip type indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isRoundTrip ? Icons.sync : Icons.arrow_forward,
                          color: Colors.black,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isRoundTrip ? 'Round Trip' : 'One Way Trip',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isRoundTrip ? 'SELECTED' : 'SELECTED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Journey card - Rapido style
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Pickup
                        _buildLocationRow(
                          icon: Icons.circle,
                          iconColor: Colors.green,
                          iconSize: 12,
                          title: 'Pickup',
                          subtitle: 'Your journey starts here',
                          showDivider: true,
                        ),
                        // Destination
                        _buildLocationRow(
                          icon: Icons.location_on,
                          iconColor: Colors.red,
                          iconSize: 18,
                          title: 'Destination',
                          subtitle:
                              isRoundTrip ? 'Drop off point' : 'Trip ends here',
                          showDivider: isRoundTrip,
                        ),
                        // Return (only for round trip)
                        if (isRoundTrip)
                          _buildLocationRow(
                            icon: Icons.flag,
                            iconColor: Colors.blue,
                            iconSize: 18,
                            title: 'Return',
                            subtitle: 'Car returned to pickup',
                            showDivider: false,
                            isReturn: true,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Fee section - Rapido style
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Fee row
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Driver Return Fee',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isRoundTrip && _isReturnToSameLocation)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'FREE',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  '₹${(isRoundTrip && hasReturnFee ? returnFee : returnFee).toInt()}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        Divider(height: 1, color: Colors.grey.shade200),

                        // Explanation
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isRoundTrip
                                      ? (_isReturnToSameLocation
                                          ? 'No additional charge as car returns to the same pickup point.'
                                          : 'Fee applies as return location differs from pickup. Charged at ₹15/km.')
                                      : 'Drivo will arrange transport for your driver to return. Charged at ₹15/km.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Additional info
                if (estimatedReturnDuration != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 10),
                          Text(
                            'Est. return time: ${estimatedReturnDuration!.toInt()} min',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required String title,
    required String subtitle,
    required bool showDivider,
    bool isReturn = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Center(
                  child: Icon(icon, color: iconColor, size: iconSize),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (isReturn) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'RETURN',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
      ],
    );
  }
}

/// Compact Rapido-style badge
class ReturnModelBadge extends StatelessWidget {
  final ReturnModel model;
  final double? returnFee;
  final String tripType;

  const ReturnModelBadge({
    super.key,
    required this.model,
    this.returnFee,
    this.tripType = 'round_trip',
  });

  @override
  Widget build(BuildContext context) {
    final isRoundTrip = tripType == 'round_trip';
    final hasFee = returnFee != null && returnFee! > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRoundTrip ? Icons.sync : Icons.arrow_forward,
            size: 16,
            color: Colors.black87,
          ),
          const SizedBox(width: 8),
          Text(
            isRoundTrip ? 'Round Trip' : 'One Way',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasFee ? AppColors.primary : Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              hasFee ? '+₹${returnFee!.toInt()}' : 'FREE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: hasFee ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
