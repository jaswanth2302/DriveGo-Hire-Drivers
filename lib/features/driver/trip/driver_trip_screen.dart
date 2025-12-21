import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/return_models.dart';
import '../../../data/services/mock_location_service.dart';

/// Driver trip states with return journey support
enum DriverTripState {
  navigatingToPickup,
  arrivedAtPickup,
  tripStarted,
  navigatingToDrop,
  arrivedAtDrop,
  // Return journey states (Model 1)
  returnJourneyStarted,
  returnInProgress,
  arrivedAtReturn,
  // Platform return states (Model 2)
  awaitingReturnArrangement,
  returnArranged,
  // Complete
  tripEnded,
}

extension DriverTripStateExtension on DriverTripState {
  String get displayName {
    switch (this) {
      case DriverTripState.navigatingToPickup:
        return 'Navigating to Pickup';
      case DriverTripState.arrivedAtPickup:
        return 'Arrived at Pickup';
      case DriverTripState.tripStarted:
        return 'Trip Started';
      case DriverTripState.navigatingToDrop:
        return 'Navigating to Drop';
      case DriverTripState.arrivedAtDrop:
        return 'Arrived at Destination';
      case DriverTripState.returnJourneyStarted:
        return 'Return Journey Started';
      case DriverTripState.returnInProgress:
        return 'Returning Car';
      case DriverTripState.arrivedAtReturn:
        return 'Car Returned';
      case DriverTripState.awaitingReturnArrangement:
        return 'Waiting for Return Cab';
      case DriverTripState.returnArranged:
        return 'Return Cab Booked';
      case DriverTripState.tripEnded:
        return 'Trip Completed';
    }
  }

  bool get isReturnPhase {
    return this == DriverTripState.returnJourneyStarted ||
        this == DriverTripState.returnInProgress ||
        this == DriverTripState.arrivedAtReturn;
  }
}

class DriverTripScreen extends ConsumerStatefulWidget {
  const DriverTripScreen({super.key});

  @override
  ConsumerState<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends ConsumerState<DriverTripScreen> {
  DriverTripState _state = DriverTripState.navigatingToPickup;
  ReturnModel _returnModel = ReturnModel.roundTrip; // From booking

  // Mock locations
  final LatLng _pickupLocation = const LatLng(12.9716, 77.5946);
  final LatLng _destinationLocation = const LatLng(12.9352, 77.6245);

  // Earnings tracking
  double _currentEarnings = 0;
  int _tripDurationMinutes = 0;

  String get _buttonText {
    switch (_state) {
      case DriverTripState.navigatingToPickup:
        return 'Arrived at Pickup';
      case DriverTripState.arrivedAtPickup:
        return 'Start Trip';
      case DriverTripState.tripStarted:
      case DriverTripState.navigatingToDrop:
        return 'Arrived at Destination';
      case DriverTripState.arrivedAtDrop:
        return _returnModel == ReturnModel.roundTrip
            ? 'Start Return Journey'
            : 'Confirm Handover';
      case DriverTripState.returnJourneyStarted:
      case DriverTripState.returnInProgress:
        return 'Arrived at Pickup';
      case DriverTripState.arrivedAtReturn:
        return 'Complete Trip';
      case DriverTripState.awaitingReturnArrangement:
        return 'Waiting...';
      case DriverTripState.returnArranged:
        return 'View Return Details';
      case DriverTripState.tripEnded:
        return 'Go Home';
      case DriverTripState.returnJourneyStarted:
        return 'Start Navigation';
    }
  }

  Color get _buttonColor {
    if (_state.isReturnPhase) {
      return AppColors.info;
    }
    switch (_state) {
      case DriverTripState.navigatingToPickup:
      case DriverTripState.arrivedAtPickup:
        return AppColors.primary;
      case DriverTripState.tripStarted:
      case DriverTripState.navigatingToDrop:
        return AppColors.secondary;
      case DriverTripState.arrivedAtDrop:
        return AppColors.success;
      case DriverTripState.awaitingReturnArrangement:
        return AppColors.textSecondary;
      case DriverTripState.returnArranged:
        return AppColors.warning;
      case DriverTripState.returnJourneyStarted:
      case DriverTripState.arrivedAtReturn:
      case DriverTripState.tripEnded:
        return AppColors.success;
      case DriverTripState.returnInProgress:
        return AppColors.info;
    }
  }

  void _onAction() {
    setState(() {
      switch (_state) {
        case DriverTripState.navigatingToPickup:
          _state = DriverTripState.arrivedAtPickup;
          break;
        case DriverTripState.arrivedAtPickup:
          _state = DriverTripState.tripStarted;
          _tripDurationMinutes = 0;
          break;
        case DriverTripState.tripStarted:
        case DriverTripState.navigatingToDrop:
          _state = DriverTripState.arrivedAtDrop;
          _tripDurationMinutes = 45; // Mock duration
          _currentEarnings = 450; // Mock earnings
          break;
        case DriverTripState.arrivedAtDrop:
          if (_returnModel == ReturnModel.roundTrip) {
            _state = DriverTripState.returnJourneyStarted;
            _showReturnJourneyStartedDialog();
          } else {
            _state = DriverTripState.awaitingReturnArrangement;
            _handlePlatformReturn();
          }
          break;
        case DriverTripState.returnJourneyStarted:
          _state = DriverTripState.returnInProgress;
          break;
        case DriverTripState.returnInProgress:
          _state = DriverTripState.arrivedAtReturn;
          _currentEarnings = 550; // Include return time
          break;
        case DriverTripState.arrivedAtReturn:
          _state = DriverTripState.tripEnded;
          _showTripCompletedDialog();
          break;
        case DriverTripState.awaitingReturnArrangement:
          // Waiting for platform
          break;
        case DriverTripState.returnArranged:
          _showReturnCabDetails();
          break;
        case DriverTripState.tripEnded:
          context.go('/driver/home');
          break;
      }
    });
  }

  void _showReturnJourneyStartedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.sync, color: AppColors.info, size: 48),
        title: const Text('Return Journey'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please return the customer\'s car to the pickup location.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Return To:',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            )),
                        const Text(
                          'Original Pickup Location',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _state = DriverTripState.returnInProgress);
            },
            child: const Text('Start Navigation'),
          ),
        ],
      ),
    );
  }

  void _handlePlatformReturn() {
    // Simulate platform arranging return
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _state = DriverTripState.returnArranged);
        _showReturnArrangedNotification();
      }
    });
  }

  void _showReturnArrangedNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Your return cab has been booked!'),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showReturnCabDetails() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.warning.withOpacity(0.2),
                  child: Icon(Icons.local_taxi, color: AppColors.warning),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Return Cab',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Arriving in 5 mins',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Driver', 'Ravi Kumar'),
                  const Divider(height: 20),
                  _buildDetailRow('Vehicle', 'Swift Dzire - KA 05 AB 1234'),
                  const Divider(height: 20),
                  _buildDetailRow('OTP', '4521'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _state = DriverTripState.tripEnded);
                  _showTripCompletedDialog();
                },
                child: const Text('Complete Trip'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showTripCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle, color: AppColors.success, size: 64),
        title: const Text('Trip Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Great job! You\'ve earned:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              '₹${_currentEarnings.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Duration: $_tripDurationMinutes mins',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (_returnModel == ReturnModel.roundTrip) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Includes return journey',
                  style: TextStyle(
                    color: AppColors.info,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/driver/home');
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_state.displayName),
        backgroundColor: _state.isReturnPhase ? AppColors.info : null,
        foregroundColor: _state.isReturnPhase ? Colors.white : null,
        actions: [
          if (_state.isReturnPhase)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Return',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          locationAsync.when(
            data: (location) => FlutterMap(
              options: MapOptions(initialCenter: location, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.drivo.app',
                ),
                // Route line
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _state.isReturnPhase
                          ? [location, _pickupLocation]
                          : [_pickupLocation, location, _destinationLocation],
                      strokeWidth: 4,
                      color: _state.isReturnPhase
                          ? AppColors.info
                          : AppColors.primary,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Pickup
                    Marker(
                      point: _pickupLocation,
                      width: 40,
                      height: 40,
                      child: Icon(
                        _state.isReturnPhase ? Icons.flag : Icons.circle,
                        color: AppColors.success,
                        size: _state.isReturnPhase ? 32 : 16,
                      ),
                    ),
                    // Destination (hide during return)
                    if (!_state.isReturnPhase)
                      Marker(
                        point: _destinationLocation,
                        width: 40,
                        height: 40,
                        child: Icon(Icons.location_on,
                            color: AppColors.secondary, size: 32),
                      ),
                    // Current location
                    Marker(
                      point: location,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _state.isReturnPhase
                              ? AppColors.info
                              : AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Icon(
                          Icons.navigation,
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

          // Bottom card
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Customer info
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surface,
                          child: Icon(Icons.person, color: AppColors.primary),
                        ),
                        title: const Text('Customer Name'),
                        subtitle: Text(
                          _state.isReturnPhase
                              ? 'Return to pickup location'
                              : 'Indiranagar, 12th Main',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.phone, color: AppColors.primary),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon:
                                  Icon(Icons.message, color: AppColors.primary),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),

                      // Return journey info banner
                      if (_state.isReturnPhase) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.sync, color: AppColors.info, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Return the car to the original pickup location',
                                  style: TextStyle(
                                    color: AppColors.info,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _buttonColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _state ==
                                  DriverTripState.awaitingReturnArrangement
                              ? null
                              : _onAction,
                          child: _state ==
                                  DriverTripState.awaitingReturnArrangement
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Arranging your return...'),
                                  ],
                                )
                              : Text(_buttonText),
                        ),
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
}
