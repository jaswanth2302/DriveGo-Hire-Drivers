import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/location_service.dart';
import 'models/ride_models.dart';
import 'services/route_service.dart';

/// Enterprise Ride Home Screen
/// Rapido-level ride booking with proper icons and real routes
class RideHomeScreen extends ConsumerStatefulWidget {
  const RideHomeScreen({super.key});

  @override
  ConsumerState<RideHomeScreen> createState() => _RideHomeScreenState();
}

class _RideHomeScreenState extends ConsumerState<RideHomeScreen> {
  final MapController _mapController = MapController();
  final RouteService _routeService = RouteService();

  // State
  RideState _state = RideState.idle;
  RideTimingMode _timingMode = RideTimingMode.now;
  DateTime? _scheduledTime;

  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  String _pickupAddress = 'Current Location';
  String _dropAddress = '';

  RideType? _selectedRideType;
  String _paymentMethod = 'Cash';

  // Route
  List<LatLng> _routePoints = [];
  double _distanceKm = 0;
  double _durationMin = 0;
  double _fare = 0;
  bool _isLoadingRoute = false;

  // Driver
  DriverInfo? _assignedDriver;
  LatLng? _driverLocation;
  List<LatLng> _driverRoutePoints = [];
  double _driverDistanceMeters = 0;
  int _driverEtaMinutes = 0;
  String _otp = '';
  Timer? _driverUpdateTimer;

  // Nearby drivers (for display)
  List<DriverInfo> _nearbyDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _loadNearbyDrivers();
  }

  @override
  void dispose() {
    _driverUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final location = await locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentLocation = location;
          _pickupLocation = location;
        });
        _mapController.move(location, 16);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(12.9716, 77.5946);
          _pickupLocation = _currentLocation;
        });
      }
    }
  }

  void _loadNearbyDrivers() {
    setState(() {
      _nearbyDrivers = DriverInfo.mockDrivers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          if (_state == RideState.idle) _buildTopBar(),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  // ==================== MAP ====================
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ?? const LatLng(12.9716, 77.5946),
        initialZoom: 16,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && _state == RideState.idle) {
            setState(() => _pickupLocation = position.center);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.drivo.app',
        ),

        // Trip route polyline (pickup to drop)
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: Colors.black,
                strokeWidth: 4,
              ),
            ],
          ),

        // Driver route to pickup (when assigned)
        if (_driverRoutePoints.isNotEmpty && _state == RideState.driverEnRoute)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _driverRoutePoints,
                color: Colors.blue,
                strokeWidth: 3,
                isDotted: true,
              ),
            ],
          ),

        // Nearby drivers - PERSON ICON (not car!)
        if (_state == RideState.idle ||
            _state == RideState.selectingRide ||
            _state == RideState.confirming)
          MarkerLayer(
            markers: _nearbyDrivers
                .where((d) => d.currentLocation != null)
                .map((driver) => Marker(
                      point: driver.currentLocation!,
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4)
                          ],
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: const Icon(Icons.person,
                            size: 20, color: Colors.blue),
                      ),
                    ))
                .toList(),
          ),

        // Assigned driver location - PERSON ICON
        if (_driverLocation != null &&
            (_state == RideState.driverEnRoute ||
                _state == RideState.driverAssigned))
          MarkerLayer(
            markers: [
              Marker(
                point: _driverLocation!,
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.4), blurRadius: 8)
                    ],
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child:
                      const Icon(Icons.person, size: 22, color: Colors.white),
                ),
              ),
            ],
          ),

        // Drop location marker
        if (_dropLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _dropLocation!,
                width: 40,
                height: 50,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.red.withOpacity(0.3), blurRadius: 6)
                        ],
                      ),
                      child: const Icon(Icons.location_on,
                          color: Colors.white, size: 18),
                    ),
                    Container(
                      width: 3,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

        // Pickup/User location - CAR ICON (user's car!)
        if (_pickupLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _pickupLocation!,
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 8)
                    ],
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.directions_car,
                      size: 22, color: Colors.black),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: const Icon(Icons.menu, size: 20),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('GPS',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BOTTOM SHEET ====================
  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: _getSheetSize(),
      minChildSize: 0.15,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildSheetContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getSheetSize() {
    switch (_state) {
      case RideState.idle:
        return 0.4;
      case RideState.selectingRide:
        return 0.55;
      case RideState.confirming:
        return 0.5;
      case RideState.searching:
        return 0.35;
      case RideState.driverAssigned:
      case RideState.driverEnRoute:
        return 0.45;
      case RideState.tripInProgress:
        return 0.35;
      case RideState.tripCompleted:
        return 0.6;
      default:
        return 0.4;
    }
  }

  Widget _buildSheetContent() {
    switch (_state) {
      case RideState.idle:
        return _buildIdleContent();
      case RideState.selectingRide:
        return _buildRideSelectionContent();
      case RideState.confirming:
        return _buildConfirmationContent();
      case RideState.searching:
        return _buildSearchingContent();
      case RideState.driverAssigned:
      case RideState.driverEnRoute:
        return _buildDriverAssignedContent();
      case RideState.driverArrived:
        return _buildDriverArrivedContent();
      case RideState.tripInProgress:
        return _buildTripInProgressContent();
      case RideState.tripCompleted:
        return _buildTripCompletedContent();
      default:
        return _buildIdleContent();
    }
  }

  // ==================== IDLE STATE ====================
  Widget _buildIdleContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timing mode selector
          _buildTimingModeSelector(),
          const SizedBox(height: 16),

          // Search bar
          GestureDetector(
            onTap: _showDestinationSearch,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Text(
                    'Where are you going?',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Saved places
          Row(
            children: [
              _buildSavedPlaceChip(Icons.home, 'Home'),
              const SizedBox(width: 10),
              _buildSavedPlaceChip(Icons.work, 'Work'),
            ],
          ),

          const SizedBox(height: 16),

          // Recent
          const Text('Recent',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          ...RecentDestination.mockRecents.map((d) => _buildRecentItem(d)),
        ],
      ),
    );
  }

  Widget _buildTimingModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTimingChip('Now', RideTimingMode.now, Icons.flash_on),
          _buildTimingChip('Tomorrow', RideTimingMode.tomorrow, Icons.wb_sunny),
          _buildTimingChip(
              'Schedule', RideTimingMode.scheduled, Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildTimingChip(String label, RideTimingMode mode, IconData icon) {
    final isSelected = _timingMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _timingMode = mode);
          if (mode == RideTimingMode.tomorrow ||
              mode == RideTimingMode.scheduled) {
            _showSchedulePicker(mode);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected ? Colors.black : Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isSelected ? Colors.black : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedPlaceChip(IconData icon, String label) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Set $label address first')),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItem(RecentDestination dest) {
    return GestureDetector(
      onTap: () => _selectDestination(
          dest.address, dest.shortName, dest.latitude, dest.longitude),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.history, size: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dest.shortName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(dest.address,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ==================== RIDE SELECTION ====================
  Widget _buildRideSelectionContent() {
    return Column(
      children: [
        // Route info bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              const Icon(Icons.directions_car, size: 18, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                '${_distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                    color: Colors.grey, shape: BoxShape.circle),
              ),
              Text('${_durationMin.toInt()} min',
                  style: TextStyle(color: Colors.grey.shade600)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _state = RideState.idle),
                child: const Icon(Icons.edit, size: 18),
              ),
            ],
          ),
        ),

        // Ride types
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose your ride',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...RideType.all.map((t) => _buildRideTypeCard(t)),
            ],
          ),
        ),

        // Continue
        if (_selectedRideType != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _state = RideState.confirming),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Continue • ₹${_fare.toInt()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRideTypeCard(RideType type) {
    final isSelected = _selectedRideType?.id == type.id;
    final fare = type.calculateFare(_distanceKm, _durationMin);

    return GestureDetector(
      onTap: () => setState(() {
        _selectedRideType = type;
        _fare = fare;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(type.icon, size: 26, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text('${type.etaMinutes} min • ${type.description}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Text('₹${fare.toInt()}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // ==================== CONFIRMATION ====================
  Widget _buildConfirmationContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _state = RideState.selectingRide),
            child: Row(children: [
              const Icon(Icons.arrow_back, size: 20),
              const SizedBox(width: 8),
              const Text('Confirm ride')
            ]),
          ),
          const SizedBox(height: 16),

          // Timing info
          if (_timingMode != RideTimingMode.now)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  Text(
                    _timingMode == RideTimingMode.tomorrow
                        ? 'Tomorrow'
                        : 'Scheduled',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800),
                  ),
                  if (_scheduledTime != null) ...[
                    const Text(' at '),
                    Text(
                      '${_scheduledTime!.hour}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800),
                    ),
                  ],
                ],
              ),
            ),

          // Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(_selectedRideType!.icon, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedRideType!.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          '${_distanceKm.toStringAsFixed(1)} km • ${_durationMin.toInt()} min',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                Text('₹${_fare.toInt()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Payment
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                    _paymentMethod == 'Cash'
                        ? Icons.money
                        : Icons.account_balance,
                    color: Colors.green),
                const SizedBox(width: 12),
                Text(_paymentMethod,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                GestureDetector(
                  onTap: _showPaymentOptions,
                  child: Text('Change',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _timingMode == RideTimingMode.now
                    ? 'Confirm Ride'
                    : 'Schedule Ride',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SEARCHING ====================
  Widget _buildSearchingContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: AppColors.primary)),
          const SizedBox(height: 20),
          const Text('Finding your driver...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Looking nearby', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => setState(() => _state = RideState.idle),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ==================== DRIVER ASSIGNED ====================
  Widget _buildDriverAssignedContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ETA bar with distance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 8),
                Text(
                  _driverDistanceMeters > 0
                      ? '${_driverDistanceMeters < 1000 ? '${_driverDistanceMeters.round()} m' : '${(_driverDistanceMeters / 1000).toStringAsFixed(1)} km'} away'
                      : 'Arriving soon',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('OTP: $_otp',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Driver info (NAME ONLY - no car details)
          Row(
            children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.person, size: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_assignedDriver?.name ?? 'Driver',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    Row(
                      children: [
                        Icon(Icons.star,
                            size: 14, color: Colors.amber.shade600),
                        Text(
                            ' ${_assignedDriver?.rating ?? 4.5} • ${_assignedDriver?.trips ?? 0} rides'),
                      ],
                    ),
                  ],
                ),
              ),
              // Call button
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calling driver...'))),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.green.shade100, shape: BoxShape.circle),
                  child:
                      Icon(Icons.phone, size: 20, color: Colors.green.shade700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ETA
          if (_driverEtaMinutes > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, size: 20),
                  const SizedBox(width: 10),
                  Text('Driver arriving in $_driverEtaMinutes min',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Cancel
          OutlinedButton(
            onPressed: _cancelRide,
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red)),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverArrivedContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Text('Driver has arrived!',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('OTP: ', style: TextStyle(fontSize: 16)),
                Text(_otp,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: 4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _state = RideState.tripInProgress),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black),
            child: const Text('Start Trip'),
          ),
        ],
      ),
    );
  }

  // ==================== TRIP IN PROGRESS ====================
  Widget _buildTripInProgressContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.navigation, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trip in Progress',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800)),
                      Text('ETA: ${_durationMin.toInt()} min',
                          style: TextStyle(
                              color: Colors.green.shade700, fontSize: 13)),
                    ],
                  ),
                ),
                Text('₹${_fare.toInt()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildSafetyButton(Icons.share_location, 'Share')),
              const SizedBox(width: 10),
              Expanded(child: _buildSafetyButton(Icons.sos, 'SOS')),
              const SizedBox(width: 10),
              Expanded(child: _buildSafetyButton(Icons.support_agent, 'Help')),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _state = RideState.tripCompleted),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black),
            child: const Text('End Trip (Demo)'),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Icon(icon, size: 22, color: Colors.grey.shade700),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  // ==================== TRIP COMPLETED ====================
  Widget _buildTripCompletedContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.check_circle, size: 50, color: Colors.green),
          const SizedBox(height: 8),
          const Text('Trip Completed!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildFareRow(
                    'Base fare', '₹${_selectedRideType!.baseFare.toInt()}'),
                _buildFareRow('Distance',
                    '₹${(_selectedRideType!.perKm * _distanceKm).toInt()}'),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('₹${_fare.toInt()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Rate your driver'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                5,
                (i) => IconButton(
                      onPressed: () {},
                      icon: Icon(i < 4 ? Icons.star : Icons.star_border,
                          color: Colors.amber, size: 32),
                    )),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _resetState,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value)
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================
  void _showDestinationSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _DestinationSearchSheet(onSelect: (a, s, lat, lng) {
        Navigator.pop(context);
        _selectDestination(a, s, lat, lng);
      }),
    );
  }

  void _showSchedulePicker(RideTimingMode mode) async {
    TimeOfDay? time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) {
      DateTime date = DateTime.now();
      if (mode == RideTimingMode.tomorrow) {
        date = date.add(const Duration(days: 1));
      } else {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (pickedDate != null) date = pickedDate;
      }
      setState(() => _scheduledTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }

  Future<void> _selectDestination(
      String address, String shortName, double lat, double lng) async {
    setState(() {
      _dropAddress = shortName;
      _dropLocation = LatLng(lat, lng);
      _isLoadingRoute = true;
    });

    // Calculate real route
    if (_pickupLocation != null) {
      final route =
          await _routeService.getDrivingRoute(_pickupLocation!, _dropLocation!);
      if (route != null && mounted) {
        setState(() {
          _routePoints = route.points;
          _distanceKm = route.distanceMeters / 1000;
          _durationMin = route.durationSeconds / 60;
          _selectedRideType = RideType.all.firstWhere((t) => t.id == 'mini');
          _fare = _selectedRideType!.calculateFare(_distanceKm, _durationMin);
          _state = RideState.selectingRide;
          _isLoadingRoute = false;
        });

        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([_pickupLocation!, _dropLocation!]),
          padding: const EdgeInsets.all(60),
        ));
      }
    }
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ...['Cash', 'UPI', 'Card'].map((m) => ListTile(
                  leading: Icon(m == 'Cash'
                      ? Icons.money
                      : m == 'UPI'
                          ? Icons.account_balance
                          : Icons.credit_card),
                  title: Text(m),
                  trailing: _paymentMethod == m
                      ? Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _paymentMethod = m);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRide() async {
    setState(() => _state = RideState.searching);

    // Simulate matching
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      final driver = DriverInfo.mockDrivers[0];
      setState(() {
        _assignedDriver = driver;
        _driverLocation = driver.currentLocation;
        _otp = '${1000 + DateTime.now().millisecond % 9000}';
        _state = RideState.driverEnRoute;
      });

      // Calculate driver route to pickup
      if (_driverLocation != null && _pickupLocation != null) {
        final driverRoute = await _routeService.getWalkingRoute(
            _driverLocation!, _pickupLocation!);
        if (driverRoute != null && mounted) {
          setState(() {
            _driverRoutePoints = driverRoute.points;
            _driverDistanceMeters = driverRoute.distanceMeters;
            _driverEtaMinutes = (driverRoute.durationSeconds / 60).ceil();
          });
        }
      }

      _startDriverTracking();
    }
  }

  void _startDriverTracking() {
    _driverUpdateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _state != RideState.driverEnRoute) {
        timer.cancel();
        return;
      }

      // Simulate driver moving closer
      if (_driverDistanceMeters > 100) {
        setState(() {
          _driverDistanceMeters -=
              50 + (50 * (DateTime.now().millisecond / 1000));
          _driverEtaMinutes =
              (_driverDistanceMeters / 80).ceil(); // ~80m per minute walk

          // Move driver marker
          if (_driverRoutePoints.isNotEmpty) {
            final progress = 1 - (_driverDistanceMeters / 500);
            final index = (progress * _driverRoutePoints.length)
                .clamp(0, _driverRoutePoints.length - 1)
                .toInt();
            _driverLocation = _driverRoutePoints[index];
          }
        });
      } else {
        setState(() => _state = RideState.driverArrived);
        timer.cancel();
      }
    });
  }

  void _cancelRide() {
    _driverUpdateTimer?.cancel();
    setState(() {
      _state = RideState.idle;
      _assignedDriver = null;
      _driverLocation = null;
      _driverRoutePoints = [];
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Ride cancelled')));
  }

  void _resetState() {
    _driverUpdateTimer?.cancel();
    setState(() {
      _state = RideState.idle;
      _dropLocation = null;
      _dropAddress = '';
      _routePoints = [];
      _selectedRideType = null;
      _assignedDriver = null;
      _driverLocation = null;
      _driverRoutePoints = [];
    });
  }
}

// ==================== DESTINATION SEARCH ====================
class _DestinationSearchSheet extends StatefulWidget {
  final Function(String, String, double, double) onSelect;
  const _DestinationSearchSheet({required this.onSelect});

  @override
  State<_DestinationSearchSheet> createState() =>
      _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<_DestinationSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  final List<Map<String, dynamic>> _locations = [
    {
      'name': 'Koramangala',
      'address': 'Koramangala 4th Block',
      'lat': 12.9352,
      'lng': 77.6245
    },
    {
      'name': 'Indiranagar',
      'address': 'Indiranagar Metro',
      'lat': 12.9784,
      'lng': 77.6408
    },
    {
      'name': 'Whitefield',
      'address': 'Whitefield, Bangalore',
      'lat': 12.9698,
      'lng': 77.7500
    },
    {
      'name': 'MG Road',
      'address': 'MG Road, Bangalore',
      'lat': 12.9756,
      'lng': 77.6066
    },
    {
      'name': 'Electronic City',
      'address': 'Electronic City',
      'lat': 12.8399,
      'lng': 77.6770
    },
    {
      'name': 'HSR Layout',
      'address': 'HSR Layout',
      'lat': 12.9116,
      'lng': 77.6446
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _locations
        : _locations
            .where(
                (l) => l['name'].toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search destination...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: sc,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final loc = filtered[i];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.location_on, size: 20),
                  ),
                  title: Text(loc['name']),
                  subtitle: Text(loc['address'],
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  onTap: () => widget.onSelect(
                      loc['address'], loc['name'], loc['lat'], loc['lng']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
