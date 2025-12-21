import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/return_models.dart';

/// Visual trip phase progress indicator
/// Shows the journey from pickup to return completion
class TripPhaseIndicator extends StatelessWidget {
  final TripPhase currentPhase;
  final ReturnModel returnModel;
  final String? returnEta;
  final bool showDetails;

  const TripPhaseIndicator({
    super.key,
    required this.currentPhase,
    required this.returnModel,
    this.returnEta,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final phases = _getPhasesForModel();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Trip Progress',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 16),

          // Phase timeline
          ...phases.asMap().entries.map((entry) {
            final index = entry.key;
            final phase = entry.value;
            final isLast = index == phases.length - 1;
            final status = _getPhaseStatus(phase);

            return _buildPhaseItem(
              context,
              phase: phase,
              status: status,
              isLast: isLast,
            );
          }),

          // Return ETA if in return phase
          if (currentPhase.isReturnPhase && returnEta != null) ...[
            const SizedBox(height: 12),
            _buildReturnEtaCard(),
          ],
        ],
      ),
    );
  }

  List<TripPhase> _getPhasesForModel() {
    switch (returnModel) {
      case ReturnModel.roundTrip:
        return [
          TripPhase.tripStarted,
          TripPhase.toDestination,
          TripPhase.arrivedAtDestination,
          TripPhase.returnInProgress,
          TripPhase.tripCompleted,
        ];
      case ReturnModel.platformReturn:
        return [
          TripPhase.tripStarted,
          TripPhase.toDestination,
          TripPhase.arrivedAtDestination,
          TripPhase.carHandedOver,
          TripPhase.tripCompleted,
        ];
      case ReturnModel.zoneBased:
        return [
          TripPhase.tripStarted,
          TripPhase.toDestination,
          TripPhase.arrivedAtDestination,
          TripPhase.tripCompleted,
        ];
    }
  }

  _PhaseStatus _getPhaseStatus(TripPhase phase) {
    final phases = _getPhasesForModel();
    final currentIndex = phases.indexOf(currentPhase);
    final phaseIndex = phases.indexOf(phase);

    if (phaseIndex < currentIndex) {
      return _PhaseStatus.completed;
    } else if (phaseIndex == currentIndex) {
      return _PhaseStatus.current;
    } else {
      return _PhaseStatus.pending;
    }
  }

  Widget _buildPhaseItem(
    BuildContext context, {
    required TripPhase phase,
    required _PhaseStatus status,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicator column
        Column(
          children: [
            _buildIndicator(status),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: status == _PhaseStatus.completed
                    ? AppColors.success
                    : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),

        // Phase info
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getPhaseDisplayName(phase),
                    style: TextStyle(
                      fontWeight: status == _PhaseStatus.current
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: status == _PhaseStatus.pending
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (status == _PhaseStatus.completed)
                  Icon(Icons.check, size: 16, color: AppColors.success)
                else if (status == _PhaseStatus.current)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(_PhaseStatus status) {
    switch (status) {
      case _PhaseStatus.completed:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 12, color: Colors.white),
        );
      case _PhaseStatus.current:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.navigation, size: 12, color: Colors.black),
        );
      case _PhaseStatus.pending:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 2),
          ),
        );
    }
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;
    IconData icon;

    if (currentPhase.isReturnPhase) {
      color = AppColors.info;
      text = 'Returning';
      icon = Icons.sync;
    } else if (currentPhase.isCompleted) {
      color = AppColors.success;
      text = 'Complete';
      icon = Icons.check_circle;
    } else {
      color = AppColors.primary;
      text = 'In Progress';
      icon = Icons.directions_car;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnEtaCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Returning your car',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
                Text(
                  'ETA: $returnEta',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.directions_car, color: AppColors.info, size: 24),
        ],
      ),
    );
  }

  String _getPhaseDisplayName(TripPhase phase) {
    switch (phase) {
      case TripPhase.tripStarted:
        return 'Trip started';
      case TripPhase.toDestination:
        return 'Driving to destination';
      case TripPhase.arrivedAtDestination:
        return 'Arrived at destination';
      case TripPhase.returnJourneyStarted:
      case TripPhase.returnInProgress:
        return 'Return journey';
      case TripPhase.arrivedAtPickup:
        return 'Car returned safely';
      case TripPhase.carHandedOver:
        return 'Car handed over';
      case TripPhase.driverReturnArranged:
        return 'Driver return arranged';
      case TripPhase.tripCompleted:
        return 'Trip completed';
      default:
        return phase.displayName;
    }
  }
}

enum _PhaseStatus { completed, current, pending }

/// Compact inline phase indicator for top bar
class CompactPhaseIndicator extends StatelessWidget {
  final TripPhase currentPhase;

  const CompactPhaseIndicator({
    super.key,
    required this.currentPhase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentPhase.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (currentPhase.isReturnPhase)
                Text(
                  'Your car is being returned',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    if (currentPhase.isReturnPhase) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.sync, color: AppColors.info, size: 18),
      );
    } else if (currentPhase.isCompleted) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check, color: AppColors.success, size: 18),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.directions_car, color: AppColors.primary, size: 18),
      );
    }
  }
}
