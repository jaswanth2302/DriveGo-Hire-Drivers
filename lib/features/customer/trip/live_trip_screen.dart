import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/trip_phase_indicator.dart';
import '../../../data/models/return_models.dart';
import '../../../data/services/mock_location_service.dart';

/// Enhanced Live Trip Screen with Return Phase Support
class LiveTripScreen extends ConsumerStatefulWidget {
  const LiveTripScreen({super.key});

  @override
  ConsumerState<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends ConsumerState<LiveTripScreen> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _formattedTime = '00:00';

  // Trip phase tracking
  TripPhase _currentPhase = TripPhase.toDestination;
  ReturnModel _returnModel = ReturnModel.roundTrip; // From booking

  // Mock locations (in real app, these come from booking)
  final LatLng _pickupLocation = const LatLng(12.9716, 77.5946);
  final LatLng _destinationLocation = const LatLng(12.9352, 77.6245);

  // Return journey state
  String? _returnEta;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final elapsed = _stopwatch.elapsed;
          _formattedTime =
              '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
        });
      }
    });

    // Simulate arrival at destination after 10 seconds (for demo)
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _currentPhase == TripPhase.toDestination) {
        _onArrivedAtDestination();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _onArrivedAtDestination() {
    setState(() {
      _currentPhase = TripPhase.arrivedAtDestination;
    });

    // Show appropriate dialog based on return model
    if (_returnModel == ReturnModel.roundTrip) {
      _showStartReturnDialog();
    } else if (_returnModel == ReturnModel.platformReturn) {
      _showHandoverDialog();
    }
  }

  void _showStartReturnDialog() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sync, color: AppColors.info, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'Arrived at Destination',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Driver will now return your car to the pickup location.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startReturnJourney();
                },
                child: const Text('Start Return Journey'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHandoverDialog() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.car_rental, color: AppColors.warning, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'Confirm Car Handover',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please confirm that your car has been safely parked at the destination.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmHandover();
                },
                child: const Text('Confirm Handover'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Stay on screen, don't confirm yet
              },
              child: const Text('Not Yet'),
            ),
          ],
        ),
      ),
    );
  }

  void _startReturnJourney() {
    setState(() {
      _currentPhase = TripPhase.returnInProgress;
      _returnEta = '15 mins'; // Mock ETA
    });

    // Simulate return journey completion after 15 seconds (for demo)
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _currentPhase == TripPhase.returnInProgress) {
        _onReturnComplete();
      }
    });
  }

  void _confirmHandover() {
    setState(() {
      _currentPhase = TripPhase.carHandedOver;
    });

    // Driver return will be handled by platform
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _currentPhase = TripPhase.tripCompleted;
        });
        _showTripCompletedDialog();
      }
    });
  }

  void _onReturnComplete() {
    setState(() {
      _currentPhase = TripPhase.arrivedAtPickup;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _currentPhase = TripPhase.tripCompleted;
        });
        _showTripCompletedDialog();
      }
    });
  }

  void _showTripCompletedDialog() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.check_circle, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'Trip Completed!',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _returnModel == ReturnModel.roundTrip
                  ? 'Your car has been safely returned.'
                  : 'Your trip has ended successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/trip/summary');
                },
                child: const Text('View Trip Summary'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _attemptEndTrip() {
    // Check if trip can be ended based on return model
    if (_returnModel == ReturnModel.roundTrip && !_currentPhase.canEndTrip) {
      _showCannotEndTripDialog();
    } else {
      context.go('/trip/summary');
    }
  }

  void _showCannotEndTripDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: AppColors.info),
            const SizedBox(width: 12),
            const Text('Trip In Progress'),
          ],
        ),
        content: const Text(
          'Your trip will end automatically when your car is safely returned to the pickup location.\n\n'
          'This ensures your vehicle is not left unattended.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationProvider);
    final canEndTrip =
        _returnModel != ReturnModel.roundTrip || _currentPhase.canEndTrip;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          locationAsync.when(
            data: (location) => FlutterMap(
              options: MapOptions(
                initialCenter: location,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.drivo.app',
                ),
                // Route line
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_pickupLocation, location, _destinationLocation],
                      strokeWidth: 4,
                      color: _currentPhase.isReturnPhase
                          ? AppColors.info
                          : AppColors.primary,
                    ),
                  ],
                ),
                // Markers
                MarkerLayer(
                  markers: [
                    // Pickup marker
                    Marker(
                      point: _pickupLocation,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.success, width: 3),
                        ),
                        child: Icon(Icons.circle,
                            color: AppColors.success, size: 16),
                      ),
                    ),
                    // Destination marker
                    Marker(
                      point: _destinationLocation,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_on,
                          color: AppColors.secondary, size: 36),
                    ),
                    // Current location / car
                    Marker(
                      point: location,
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentPhase.isReturnPhase
                              ? AppColors.info
                              : AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: (_currentPhase.isReturnPhase
                                      ? AppColors.info
                                      : AppColors.primary)
                                  .withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _currentPhase.isReturnPhase
                              ? Icons.sync
                              : Icons.directions_car,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Map Error')),
          ),

          // Top Phase Indicator
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CompactPhaseIndicator(currentPhase: _currentPhase),
            ),
          ),

          // Return Progress Banner (shown during return)
          if (_currentPhase.isReturnPhase)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: _buildReturnProgressBanner(),
            ),

          // Bottom Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Trip info row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentPhase.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Duration: $_formattedTime',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Return model badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _returnModel == ReturnModel.roundTrip
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _returnModel == ReturnModel.roundTrip
                                      ? Icons.sync
                                      : Icons.location_on,
                                  size: 16,
                                  color: _returnModel == ReturnModel.roundTrip
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _returnModel.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _returnModel == ReturnModel.roundTrip
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          // SOS Button
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () {
                                // SOS action
                              },
                              icon: const Icon(Icons.emergency),
                              label: const Text('SOS'),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // End Trip Button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canEndTrip
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _attemptEndTrip,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!canEndTrip) ...[
                                    Icon(Icons.lock, size: 18),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(canEndTrip
                                      ? 'End Trip'
                                      : 'Ends After Return'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnProgressBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.info.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sync, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Returning Your Car',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_returnEta != null)
                  Text(
                    'ETA: $_returnEta',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.directions_car, color: Colors.white, size: 32),
        ],
      ),
    );
  }
}
