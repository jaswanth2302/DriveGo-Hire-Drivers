import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../data/models/booking_models.dart';

class DriverTrackingScreen extends ConsumerStatefulWidget {
  final Driver driver;
  final LatLng pickupLocation;
  final String pickupAddress;
  final LatLng destinationLocation;
  final String destinationAddress;
  final VoidCallback onStartTrip;

  const DriverTrackingScreen({
    super.key,
    required this.driver,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.destinationLocation,
    required this.destinationAddress,
    required this.onStartTrip,
  });

  @override
  ConsumerState<DriverTrackingScreen> createState() =>
      _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends ConsumerState<DriverTrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _driverMoveController;
  late LatLng _driverLocation;
  late LatLng _startLocation;
  int _etaMinutes = 5;
  Timer? _updateTimer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();

    // Driver starts 1-2 km away
    final random = Random();
    _startLocation = LatLng(
      widget.pickupLocation.latitude + (random.nextDouble() - 0.5) * 0.02,
      widget.pickupLocation.longitude + (random.nextDouble() - 0.5) * 0.02,
    );
    _driverLocation = _startLocation;

    _driverMoveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Simulate driver movement towards pickup
    _updateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _moveDriverCloser();
      }
    });
  }

  void _moveDriverCloser() {
    final progress = (_etaMinutes <= 1) ? 0.95 : (5 - _etaMinutes) / 5;
    final lat = _startLocation.latitude +
        (widget.pickupLocation.latitude - _startLocation.latitude) * progress;
    final lng = _startLocation.longitude +
        (widget.pickupLocation.longitude - _startLocation.longitude) * progress;

    setState(() {
      _driverLocation = LatLng(lat, lng);
      if (_etaMinutes > 0) _etaMinutes--;
    });

    if (_etaMinutes <= 0) {
      _updateTimer?.cancel();
      // Driver arrived
      _showDriverArrivedDialog();
    }
  }

  void _showDriverArrivedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 32),
            const SizedBox(width: 12),
            const Text('Driver Arrived!'),
          ],
        ),
        content: const Text(
          'Your driver has arrived at the pickup location. Please meet them at the pickup point.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onStartTrip();
            },
            child: const Text('Start Trip'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _driverMoveController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map with driver location
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.pickupLocation,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.drivo.app',
              ),
              // Route line (driver to pickup)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_driverLocation, widget.pickupLocation],
                    strokeWidth: 4,
                    color: AppColors.secondary,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              // Markers
              MarkerLayer(
                markers: [
                  // Driver marker (animated)
                  Marker(
                    point: _driverLocation,
                    width: 50,
                    height: 50,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.directions_car,
                                color: AppColors.secondary,
                                size: 28,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Pickup marker
                  Marker(
                    point: widget.pickupLocation,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top bar with back button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ScaleButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom driver details card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // ETA Banner
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              color: Colors.black, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver arriving in',
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  children: [
                                    AnimatedCounter(
                                      value: _etaMinutes,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      ' min',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'On the way',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Driver info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Driver avatar
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.person,
                                size: 30, color: Colors.black),
                          ),
                          const SizedBox(width: 16),
                          // Driver details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.driver.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${widget.driver.carModel} • ${widget.driver.plateNumber}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        color: Colors.amber, size: 16),
                                    Text(
                                      ' ${widget.driver.rating}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const Text(' • 500+ trips'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.phone,
                              label: 'Call',
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.message,
                              label: 'Message',
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.share,
                              label: 'Share Trip',
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Trip info
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildTripInfoRow(
                            icon: Icons.circle,
                            iconColor: AppColors.primary,
                            label: 'Pickup',
                            value: widget.pickupAddress,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Container(
                              width: 2,
                              height: 20,
                              color: AppColors.border,
                            ),
                          ),
                          _buildTripInfoRow(
                            icon: Icons.location_on,
                            iconColor: AppColors.secondary,
                            label: 'Drop',
                            value: widget.destinationAddress,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ScaleButton(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.secondary),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
