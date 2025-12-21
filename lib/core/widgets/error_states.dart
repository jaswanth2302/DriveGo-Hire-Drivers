import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Error state widget for when no drivers are found
class NoDriversFoundState extends StatelessWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onNotifyMe;

  const NoDriversFoundState({
    super.key,
    this.onRetry,
    this.onNotifyMe,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_transfer_rounded,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 24),
            Text(
              'No Drivers Available',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'All our drivers are currently busy. Please try again in a few minutes.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onNotifyMe,
              child: const Text('Notify me when available'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state widget for network errors
class NetworkErrorState extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorState({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 24),
            Text(
              'No Internet Connection',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state widget for GPS/Location errors
class GPSErrorState extends StatelessWidget {
  final VoidCallback? onEnableLocation;

  const GPSErrorState({
    super.key,
    this.onEnableLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 24),
            Text(
              'Location Access Required',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We need your location to find nearby drivers and provide accurate service.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onEnableLocation,
              child: const Text('Enable Location'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state widget for trip cancellation
class TripCancelledState extends StatelessWidget {
  final String reason;
  final VoidCallback? onBookAgain;
  final VoidCallback? onContactSupport;

  const TripCancelledState({
    super.key,
    required this.reason,
    this.onBookAgain,
    this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cancel_rounded,
              size: 80,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Trip Cancelled',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onBookAgain,
              child: const Text('Book Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onContactSupport,
              child: const Text('Contact Support'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
