import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/location_service.dart';
import '../../../data/models/booking_models.dart';

class DriverSearchScreen extends ConsumerStatefulWidget {
  final LatLng pickupLocation;
  final String pickupAddress;
  final LatLng destinationLocation;
  final String destinationAddress;
  final Function(Driver) onDriverFound;
  final VoidCallback onNoDrivers;

  const DriverSearchScreen({
    super.key,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.destinationLocation,
    required this.destinationAddress,
    required this.onDriverFound,
    required this.onNoDrivers,
  });

  @override
  ConsumerState<DriverSearchScreen> createState() => _DriverSearchScreenState();
}

class _DriverSearchScreenState extends ConsumerState<DriverSearchScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _radiusController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _radiusAnimation;

  // Search state
  int _currentRadiusIndex = 0;
  final List<double> _searchRadii = [0.5, 1.0, 2.0, 5.0]; // km
  final List<String> _radiusLabels = ['500m', '1 km', '2 km', '5 km'];
  bool _searchComplete = false;
  Timer? _searchTimer;
  Timer? _radiusTimer;
  int _elapsedSeconds = 0;

  // Mock nearby drivers (for animation)
  final List<LatLng> _nearbyDrivers = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSearch();
  }

  void _initAnimations() {
    // Pulse animation for center marker
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Radius expansion animation
    _radiusController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _radiusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _radiusController, curve: Curves.easeOutCubic),
    );
  }

  void _startSearch() {
    // Start with first radius
    _expandToNextRadius();

    // Elapsed time counter
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);

        // Generate random nearby drivers occasionally
        if (_elapsedSeconds % 2 == 0 && _nearbyDrivers.length < 5) {
          _addRandomDriver();
        }

        // Check timeout (5 minutes = 300 seconds, using 30 for demo)
        if (_elapsedSeconds >= 30) {
          _handleNoDriversFound();
        }
      }
    });
  }

  void _expandToNextRadius() {
    if (_currentRadiusIndex >= _searchRadii.length) {
      // All radii searched, wait a bit more then fail
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_searchComplete) {
          _handleNoDriversFound();
        }
      });
      return;
    }

    _radiusController.forward(from: 0.0);

    // Move to next radius after delay
    _radiusTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_searchComplete) {
        setState(() => _currentRadiusIndex++);
        _expandToNextRadius();

        // Simulate finding driver at random radius
        if (_currentRadiusIndex >= 2 && _random.nextDouble() > 0.3) {
          _handleDriverFound();
        }
      }
    });
  }

  void _addRandomDriver() {
    final lat =
        widget.pickupLocation.latitude + (_random.nextDouble() - 0.5) * 0.02;
    final lng =
        widget.pickupLocation.longitude + (_random.nextDouble() - 0.5) * 0.02;
    setState(() {
      _nearbyDrivers.add(LatLng(lat, lng));
    });
  }

  void _handleDriverFound() {
    _searchComplete = true;
    _searchTimer?.cancel();
    _radiusTimer?.cancel();

    // Create mock driver
    final driver = Driver(
      id: 'drv_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Rajesh Kumar',
      carModel: 'Swift Dzire',
      plateNumber: 'KA 51 AB 1234',
      rating: 4.8,
      photoUrl: 'https://i.pravatar.cc/150?u=rajesh',
    );

    widget.onDriverFound(driver);
  }

  void _handleNoDriversFound() {
    _searchComplete = true;
    _searchTimer?.cancel();
    _radiusTimer?.cancel();
    widget.onNoDrivers();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _radiusController.dispose();
    _searchTimer?.cancel();
    _radiusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map background
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.pickupLocation,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.drivo.app',
              ),
              // Animated search radius
              AnimatedBuilder(
                animation: _radiusAnimation,
                builder: (context, child) {
                  return CircleLayer(
                    circles: [
                      // Outer glow
                      CircleMarker(
                        point: widget.pickupLocation,
                        radius: _searchRadii[_currentRadiusIndex.clamp(0, 3)] *
                            1000 *
                            _radiusAnimation.value *
                            0.5,
                        color: AppColors.primary.withOpacity(0.1),
                        borderColor: AppColors.primary.withOpacity(0.3),
                        borderStrokeWidth: 2,
                      ),
                      // Inner search area
                      CircleMarker(
                        point: widget.pickupLocation,
                        radius: _searchRadii[_currentRadiusIndex.clamp(0, 3)] *
                            1000 *
                            _radiusAnimation.value *
                            0.3,
                        color: AppColors.primary.withOpacity(0.2),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 3,
                      ),
                    ],
                  );
                },
              ),
              // Nearby drivers markers
              MarkerLayer(
                markers: [
                  // Pickup location
                  Marker(
                    point: widget.pickupLocation,
                    width: 60,
                    height: 60,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.black,
                              size: 30,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Nearby drivers
                  ..._nearbyDrivers.map((loc) => Marker(
                        point: loc,
                        width: 40,
                        height: 40,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.directions_car,
                                    color: AppColors.secondary, size: 20),
                              ),
                            );
                          },
                        ),
                      )),
                ],
              ),
            ],
          ),

          // Bottom info card
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated searching indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPulsingDot(0),
                      _buildPulsingDot(1),
                      _buildPulsingDot(2),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status text
                  Text(
                    'Searching for drivers',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Current search radius
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      'Searching within ${_radiusLabels[_currentRadiusIndex.clamp(0, 3)]}...',
                      key: ValueKey(_currentRadiusIndex),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Progress indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentRadiusIndex + 1) / _searchRadii.length,
                      backgroundColor: AppColors.surface,
                      color: AppColors.primary,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time elapsed
                  Text(
                    'Time elapsed: ${_elapsedSeconds}s',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  // Cancel button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel Search',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.5 + (value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
