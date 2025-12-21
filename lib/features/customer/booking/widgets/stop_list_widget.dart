import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/booking_models.dart';

/// A widget that displays a single location card with optional add/remove buttons
class LocationStopCard extends StatelessWidget {
  final TripStop stop;
  final int index;
  final bool showAddButton;
  final bool showRemoveButton;
  final VoidCallback onTap;
  final VoidCallback? onAddStop;
  final VoidCallback? onRemove;

  const LocationStopCard({
    super.key,
    required this.stop,
    required this.index,
    this.showAddButton = false,
    this.showRemoveButton = false,
    required this.onTap,
    this.onAddStop,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The location card
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _buildIcon(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getLabel(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        stop.address.isNotEmpty
                            ? stop.address
                            : _getPlaceholder(),
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showRemoveButton)
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.error, size: 20),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
        ),

        // Connection line and add button
        if (showAddButton) _buildConnectionWithAddButton(context),
      ],
    );
  }

  Widget _buildIcon() {
    switch (stop.type) {
      case StopType.pickup:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.circle, color: AppColors.primary, size: 12),
        );
      case StopType.stop:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${index}',
            style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      case StopType.destination:
        return Icon(Icons.location_on, color: AppColors.secondary, size: 24);
    }
  }

  String _getLabel() {
    switch (stop.type) {
      case StopType.pickup:
        return 'Pickup';
      case StopType.stop:
        return 'Stop $index';
      case StopType.destination:
        return 'Destination';
    }
  }

  String _getPlaceholder() {
    switch (stop.type) {
      case StopType.pickup:
        return 'Select pickup location';
      case StopType.stop:
        return 'Select stop location';
      case StopType.destination:
        return 'Where to?';
    }
  }

  Widget _buildConnectionWithAddButton(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 28),
        Column(
          children: [
            Container(width: 2, height: 12, color: AppColors.border),
            GestureDetector(
              onTap: onAddStop,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.black, size: 16),
              ),
            ),
            Container(width: 2, height: 12, color: AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onAddStop,
            child: Text(
              'Add stop',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A widget that displays a journey leg with all its stops
class JourneyLegWidget extends StatelessWidget {
  final String title;
  final LegType legType;
  final List<TripStop> stops;
  final Function(int index) onStopTap;
  final Function(int afterIndex) onAddStop;
  final Function(String stopId) onRemoveStop;

  const JourneyLegWidget({
    super.key,
    required this.title,
    required this.legType,
    required this.stops,
    required this.onStopTap,
    required this.onAddStop,
    required this.onRemoveStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: legType == LegType.outward
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                legType == LegType.outward
                    ? Icons.arrow_forward
                    : Icons.arrow_back,
                size: 16,
                color: legType == LegType.outward
                    ? AppColors.primary
                    : AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: legType == LegType.outward
                      ? Colors.black87
                      : AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stops list
        ...List.generate(stops.length, (index) {
          final stop = stops[index];
          final isLast = index == stops.length - 1;
          final isIntermediateStop = stop.type == StopType.stop;

          return LocationStopCard(
            stop: stop,
            index: isIntermediateStop ? index : 0,
            showAddButton: !isLast,
            showRemoveButton: isIntermediateStop,
            onTap: () => onStopTap(index),
            onAddStop: () => onAddStop(index),
            onRemove: () => onRemoveStop(stop.id),
          );
        }),
      ],
    );
  }
}

/// Simple connection line widget
class ConnectionLine extends StatelessWidget {
  final double height;

  const ConnectionLine({super.key, this.height = 30});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: Container(
        width: 2,
        height: height,
        color: AppColors.border,
      ),
    );
  }
}
