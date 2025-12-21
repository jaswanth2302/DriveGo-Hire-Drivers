import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/routing_service.dart';
import '../../../data/models/booking_models.dart';
import '../../../data/models/return_models.dart';
import '../../../data/models/car_type_models.dart';
import '../../../data/models/pricing_models.dart';
import 'location_search_screen.dart';
import 'driver_search_screen.dart';
import 'driver_tracking_screen.dart';
import 'no_drivers_screen.dart';
import 'widgets/return_mode_selector.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  int _currentStep = 0;
  String _selectedService = 'Hourly';
  bool _isSearching = false;
  Driver? _assignedDriver;
  final _uuid = const Uuid();

  // Multi-stop location data
  List<TripStop> _outwardStops = [];
  List<TripStop> _returnStops = [];

  // Legacy location data (for compatibility)
  LatLng? _pickupLocation;
  String? _pickupAddress;
  LatLng? _destinationLocation;
  String? _destinationAddress;

  // Route data
  RouteInfo? _routeInfo;
  bool _isLoadingRoute = false;

  // Schedule data
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _scheduledTime = TimeOfDay.now();
  bool _isScheduledRide = false; // false = Now, true = Scheduled

  // Trip type: 'round_trip', 'one_way', 'one_day'
  String _tripType = 'round_trip';

  // Return model selection
  ReturnModel _selectedReturnModel = ReturnModel.roundTrip;

  // One-way trip: Should driver return car to pickup location?
  bool _returnCarToPickup = false;

  // Car type selection
  CarType? _selectedCarType;

  // Pricing - Enterprise System
  int _estimatedDrivingHours = 2; // Minimum 2 hours
  int _declaredWaitingHours = 0; // Pre-declared waiting time

  @override
  void initState() {
    super.initState();
    _initializeStops();
    _loadCurrentLocation();
  }

  void _initializeStops() {
    // Initialize with empty pickup and destination
    _outwardStops = [
      TripStop(
        id: _uuid.v4(),
        address: '',
        latitude: 0,
        longitude: 0,
        type: StopType.pickup,
      ),
      TripStop(
        id: _uuid.v4(),
        address: '',
        latitude: 0,
        longitude: 0,
        type: StopType.destination,
      ),
    ];

    _returnStops = [
      TripStop(
        id: _uuid.v4(),
        address: '',
        latitude: 0,
        longitude: 0,
        type: StopType.pickup,
      ),
      TripStop(
        id: _uuid.v4(),
        address: '',
        latitude: 0,
        longitude: 0,
        type: StopType.destination,
      ),
    ];
  }

  Future<void> _loadCurrentLocation() async {
    final locationService = ref.read(locationServiceProvider);
    final location = await locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _pickupLocation = location;
        _pickupAddress = 'Current Location';

        // Update outward pickup
        _outwardStops[0] = TripStop(
          id: _outwardStops[0].id,
          address: 'Current Location',
          latitude: location.latitude,
          longitude: location.longitude,
          type: StopType.pickup,
        );

        // Update return destination (same as original pickup)
        _returnStops[_returnStops.length - 1] = TripStop(
          id: _returnStops.last.id,
          address: 'Current Location',
          latitude: location.latitude,
          longitude: location.longitude,
          type: StopType.destination,
        );
      });
    }
  }

  // ==================== STOP MANAGEMENT METHODS ====================

  Future<void> _selectStopLocation(bool isOutward, int index) async {
    final stop = isOutward ? _outwardStops[index] : _returnStops[index];
    final title = stop.type == StopType.pickup
        ? 'Select Pickup Location'
        : stop.type == StopType.destination
            ? 'Select Destination'
            : 'Select Stop Location';

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => LocationSearchScreen(title: title),
      ),
    );

    if (result != null && mounted) {
      final location = result['location'] as LatLng;
      final address = result['address'] as String;

      setState(() {
        final updatedStop = TripStop(
          id: stop.id,
          address: address,
          latitude: location.latitude,
          longitude: location.longitude,
          type: stop.type,
        );

        if (isOutward) {
          _outwardStops[index] = updatedStop;

          // Sync with legacy variables
          if (index == 0) {
            _pickupLocation = location;
            _pickupAddress = address;
            // Also update return destination
            _returnStops[_returnStops.length - 1] = TripStop(
              id: _returnStops.last.id,
              address: address,
              latitude: location.latitude,
              longitude: location.longitude,
              type: StopType.destination,
            );
          } else if (index == _outwardStops.length - 1) {
            _destinationLocation = location;
            _destinationAddress = address;
            // Also update return pickup
            _returnStops[0] = TripStop(
              id: _returnStops[0].id,
              address: address,
              latitude: location.latitude,
              longitude: location.longitude,
              type: StopType.pickup,
            );
          }
        } else {
          _returnStops[index] = updatedStop;
        }
      });
      _calculateRoute();
    }
  }

  void _addStopAfter(bool isOutward, int afterIndex) {
    setState(() {
      final newStop = TripStop(
        id: _uuid.v4(),
        address: '',
        latitude: 0,
        longitude: 0,
        type: StopType.stop,
      );

      if (isOutward) {
        _outwardStops.insert(afterIndex + 1, newStop);
      } else {
        _returnStops.insert(afterIndex + 1, newStop);
      }
    });
  }

  void _removeStop(bool isOutward, String stopId) {
    setState(() {
      if (isOutward) {
        _outwardStops.removeWhere((s) => s.id == stopId);
      } else {
        _returnStops.removeWhere((s) => s.id == stopId);
      }
    });
    _calculateRoute();
  }

  Future<void> _calculateRoute() async {
    if (_pickupLocation == null || _destinationLocation == null) return;

    setState(() => _isLoadingRoute = true);

    final routingService = ref.read(routingServiceProvider);
    final route = await routingService.getRoute(
      _pickupLocation!,
      _destinationLocation!,
    );

    if (mounted) {
      setState(() {
        _routeInfo = route;
        _isLoadingRoute = false;
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination')),
      );
      return;
    }
    setState(() => _currentStep++);
  }

  Future<void> _confirmBooking() async {
    if (_pickupLocation == null || _destinationLocation == null) return;

    // Navigate to premium driver search screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DriverSearchScreen(
          pickupLocation: _pickupLocation!,
          pickupAddress: _pickupAddress ?? 'Pickup',
          destinationLocation: _destinationLocation!,
          destinationAddress: _destinationAddress ?? 'Destination',
          onDriverFound: (driver) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => DriverTrackingScreen(
                  driver: driver,
                  pickupLocation: _pickupLocation!,
                  pickupAddress: _pickupAddress ?? 'Pickup',
                  destinationLocation: _destinationLocation!,
                  destinationAddress: _destinationAddress ?? 'Destination',
                  onStartTrip: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    context.push('/trip/live');
                  },
                ),
              ),
            );
          },
          onNoDrivers: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => NoDriversScreen(
                  onRetry: () {
                    Navigator.of(context).pop();
                    _confirmBooking();
                  },
                  onGoBack: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_assignedDriver != null) {
      return _buildDriverFoundView();
    }

    if (_isSearching) {
      return _buildSearchingView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Booking'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / 6, // Updated to 6 steps
            backgroundColor: AppColors.surfaceVariant,
            color: AppColors.primary,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildLocationStep(),
                _buildCarTypeStep(), // NEW: Car type selection
                _buildScheduleStep(),
                _buildServiceStep(),
                _buildReturnModelStep(),
                _buildConfirmStep(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _currentStep == 5 ? _confirmBooking : _nextStep,
                  child: Text(_currentStep == 5
                      ? 'Confirm & Book'
                      : AppStrings.continueText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return FadeSlideTransition(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where are you going?',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            // Trip Type Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTripTypeChip('round_trip', 'Round Trip', Icons.sync),
                  _buildTripTypeChip('one_way', 'One Way', Icons.arrow_forward),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==================== OUTWARD JOURNEY ====================
            _buildJourneySection(
              title: 'Outward Journey',
              icon: Icons.arrow_forward,
              color: AppColors.primary,
              stops: _outwardStops,
              isOutward: true,
            ),

            // ==================== CAR RETURN OPTION (One Way Only) ====================
            if (_tripType == 'one_way') ...[
              const SizedBox(height: 20),
              _buildCarReturnOption(),
            ],

            // ==================== RETURN JOURNEY (Round Trip Only) ====================
            if (_tripType == 'round_trip') ...[
              const SizedBox(height: 24),
              _buildJourneySection(
                title: 'Return Journey',
                icon: Icons.arrow_back,
                color: AppColors.secondary,
                stops: _returnStops,
                isOutward: false,
              ),
            ],

            // Route Info
            if (_isLoadingRoute)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_routeInfo != null) ...[
              const SizedBox(height: 24),
              _buildRouteInfoCard(),
              const SizedBox(height: 16),
              _buildEnhancedMapPreview(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJourneySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<TripStop> stops,
    required bool isOutward,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
          final stopNumber = stops
              .sublist(0, index + 1)
              .where((s) => s.type == StopType.stop)
              .length;

          return Column(
            children: [
              // Stop card
              _buildStopCard(
                stop: stop,
                index: stopNumber,
                isOutward: isOutward,
                listIndex: index,
                showRemove: isIntermediateStop,
              ),

              // Add stop button (show between all stops except after the last one)
              if (!isLast) _buildAddStopButton(isOutward, index),
            ],
          );
        }),
      ],
    );
  }

  // ==================== CAR RETURN OPTION FOR ONE-WAY ====================
  Widget _buildCarReturnOption() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Driver Return',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'After reaching destination, should the driver return your car to pickup location?',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 16),

          // Toggle options
          Row(
            children: [
              Expanded(
                child: _buildReturnOptionCard(
                  title: 'Yes, return car',
                  subtitle: 'Driver brings car back',
                  icon: Icons.replay,
                  isSelected: _returnCarToPickup,
                  onTap: () => setState(() => _returnCarToPickup = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildReturnOptionCard(
                  title: 'No, end trip',
                  subtitle: 'Keep car at destination',
                  icon: Icons.location_on,
                  isSelected: !_returnCarToPickup,
                  onTap: () => setState(() => _returnCarToPickup = false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.payments, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Driver return fee applies in both cases (driver needs to get home)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 24,
                color: isSelected ? Colors.black : Colors.grey.shade600),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? Colors.black : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.black54 : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopCard({
    required TripStop stop,
    required int index,
    required bool isOutward,
    required int listIndex,
    required bool showRemove,
  }) {
    return GestureDetector(
      onTap: () => _selectStopLocation(isOutward, listIndex),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _buildStopIcon(stop, index),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStopLabel(stop, index),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    stop.address.isNotEmpty
                        ? stop.address
                        : _getStopPlaceholder(stop),
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showRemove)
              IconButton(
                icon: Icon(Icons.close, color: AppColors.error, size: 20),
                onPressed: () => _removeStop(isOutward, stop.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildStopIcon(TripStop stop, int index) {
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
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      case StopType.destination:
        return Icon(Icons.location_on, color: AppColors.secondary, size: 24);
    }
  }

  String _getStopLabel(TripStop stop, int index) {
    switch (stop.type) {
      case StopType.pickup:
        return 'Pickup';
      case StopType.stop:
        return 'Stop $index';
      case StopType.destination:
        return 'Destination';
    }
  }

  String _getStopPlaceholder(TripStop stop) {
    switch (stop.type) {
      case StopType.pickup:
        return 'Select pickup location';
      case StopType.stop:
        return 'Select stop location';
      case StopType.destination:
        return 'Where to?';
    }
  }

  Widget _buildAddStopButton(bool isOutward, int afterIndex) {
    return Row(
      children: [
        const SizedBox(width: 28),
        Column(
          children: [
            Container(width: 2, height: 10, color: AppColors.border),
            GestureDetector(
              onTap: () => _addStopAfter(isOutward, afterIndex),
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
                child: const Icon(Icons.add, color: Colors.black, size: 14),
              ),
            ),
            Container(width: 2, height: 10, color: AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _addStopAfter(isOutward, afterIndex),
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

  Widget _buildEnhancedMapPreview() {
    // Collect all stops with valid locations
    final allOutwardPoints = _outwardStops
        .where((s) => s.latitude != 0 && s.longitude != 0)
        .map((s) => LatLng(s.latitude, s.longitude))
        .toList();

    final allReturnPoints = _tripType == 'round_trip'
        ? _returnStops
            .where((s) => s.latitude != 0 && s.longitude != 0)
            .map((s) => LatLng(s.latitude, s.longitude))
            .toList()
        : <LatLng>[];

    if (allOutwardPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: allOutwardPoints.first,
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.drivo.app',
            ),
            // Outward route line
            if (allOutwardPoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: allOutwardPoints,
                    strokeWidth: 4,
                    color: AppColors.primary,
                  ),
                ],
              ),
            // Return route line
            if (allReturnPoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: allReturnPoints,
                    strokeWidth: 4,
                    color: AppColors.secondary,
                  ),
                ],
              ),
            // Markers for all stops
            MarkerLayer(
              markers: [
                // Car icon at pickup
                if (allOutwardPoints.isNotEmpty)
                  Marker(
                    point: allOutwardPoints.first,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.directions_car,
                          color: Colors.black, size: 20),
                    ),
                  ),
                // Intermediate outward stops
                ...List.generate(
                  _outwardStops.length,
                  (i) {
                    final stop = _outwardStops[i];
                    if (stop.latitude == 0 || i == 0) return null;
                    return Marker(
                      point: LatLng(stop.latitude, stop.longitude),
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: stop.type == StopType.destination
                              ? AppColors.secondary
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: stop.type == StopType.destination
                                ? AppColors.secondary
                                : AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: stop.type == StopType.destination
                              ? Icon(Icons.flag, color: Colors.white, size: 16)
                              : Text(
                                  '${i}',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ).whereType<Marker>(),
                // Return journey markers
                if (_tripType == 'round_trip')
                  ...List.generate(
                    _returnStops.length,
                    (i) {
                      final stop = _returnStops[i];
                      if (stop.latitude == 0 ||
                          i == 0 ||
                          i == _returnStops.length - 1) return null;
                      return Marker(
                        point: LatLng(stop.latitude, stop.longitude),
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.secondary, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              'R${i}',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ).whereType<Marker>(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required VoidCallback onTap,
  }) {
    return ScaleButton(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    address,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildTripTypeChip(String type, String label, IconData icon) {
    final isSelected = _tripType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tripType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRouteInfoItem(
            icon: Icons.route,
            value: '${_routeInfo!.distanceKm.toStringAsFixed(1)} km',
            label: 'Distance',
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          _buildRouteInfoItem(
            icon: Icons.schedule,
            value: '${_routeInfo!.durationMinutes} min',
            label: 'Duration',
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          _buildRouteInfoItem(
            icon: Icons.currency_rupee,
            value:
                '₹${ref.read(routingServiceProvider).calculateFare(_routeInfo!.distanceKm, _selectedService.toLowerCase()).toStringAsFixed(0)}',
            label: 'Est. Fare',
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.secondary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildMapPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _pickupLocation!,
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.drivo.app',
            ),
            // Route line
            if (_routeInfo != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routeInfo!.points,
                    strokeWidth: 4,
                    color: AppColors.primary,
                  ),
                ],
              ),
            // Markers
            MarkerLayer(
              markers: [
                if (_pickupLocation != null)
                  Marker(
                    point: _pickupLocation!,
                    width: 40,
                    height: 40,
                    child:
                        Icon(Icons.circle, color: AppColors.primary, size: 16),
                  ),
                if (_destinationLocation != null)
                  Marker(
                    point: _destinationLocation!,
                    width: 40,
                    height: 40,
                    child: Icon(Icons.location_on,
                        color: AppColors.secondary, size: 32),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CAR TYPE STEP ====================

  final CarTypeService _carTypeService = CarTypeService();
  TransmissionType _selectedTransmission = TransmissionType.manual;
  List<CarType> _carTypes = [];
  bool _isLoadingCarTypes = false;

  Future<void> _loadCarTypes() async {
    setState(() => _isLoadingCarTypes = true);
    final types = await _carTypeService.getCarTypes(_selectedTransmission);
    if (mounted) {
      setState(() {
        _carTypes = types;
        _isLoadingCarTypes = false;
      });
    }
  }

  Widget _buildCarTypeStep() {
    if (_carTypes.isEmpty && !_isLoadingCarTypes) {
      _loadCarTypes();
    }

    return FadeSlideTransition(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Your car',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
            ),
          ),

          // Transmission Toggle - Premium Pill Style
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Stack(
                children: [
                  // Animated selector
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: _selectedTransmission == TransmissionType.manual
                        ? 3
                        : null,
                    right: _selectedTransmission == TransmissionType.automatic
                        ? 3
                        : null,
                    top: 3,
                    bottom: 3,
                    width: MediaQuery.of(context).size.width / 2 - 23,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(19),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_selectedTransmission !=
                                TransmissionType.manual) {
                              setState(() {
                                _selectedTransmission = TransmissionType.manual;
                                _selectedCarType = null;
                              });
                              _loadCarTypes();
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedTransmission ==
                                        TransmissionType.manual
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: _selectedTransmission ==
                                        TransmissionType.manual
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              child: const Text('Manual'),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_selectedTransmission !=
                                TransmissionType.automatic) {
                              setState(() {
                                _selectedTransmission =
                                    TransmissionType.automatic;
                                _selectedCarType = null;
                              });
                              _loadCarTypes();
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedTransmission ==
                                        TransmissionType.automatic
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: _selectedTransmission ==
                                        TransmissionType.automatic
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              child: const Text('Automatic'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Subtle note for automatic
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _selectedTransmission == TransmissionType.automatic
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text(
                      'AT-trained drivers only',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // Car Type List - Compact Cards
          Expanded(
            child: _isLoadingCarTypes
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _carTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final carType = _carTypes[index];
                      final isSelected = _selectedCarType?.id == carType.id;
                      return _buildCompactCarCard(carType, isSelected);
                    },
                  ),
          ),

          // Selection footer
          if (_selectedCarType != null)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.border.withOpacity(0.5)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCarType!.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _selectedCarType!.exampleModels.take(2).join(', '),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${_selectedCarType!.pricePerHour.toInt()}/hr',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactCarCard(CarType carType, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCarType = carType);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border.withOpacity(0.6),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary.withOpacity(0.4),
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        carType.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textPrimary.withOpacity(0.9),
                        ),
                      ),
                      if (carType.category == CarCategory.electric) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EV',
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    carType.exampleModels.take(3).join(' • '),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Text(
              '₹${carType.pricePerHour.toInt()}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '/hr',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleStep() {
    return FadeSlideTransition(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('When do you need the driver?',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),

            // Quick Options
            _buildScheduleOption(
              icon: Icons.flash_on,
              title: 'Ride Now',
              subtitle: 'Get a driver immediately',
              isSelected: !_isScheduledRide,
              onTap: () {
                setState(() {
                  _isScheduledRide = false;
                  _scheduledDate = DateTime.now();
                  _scheduledTime = TimeOfDay.now();
                });
              },
            ),

            _buildScheduleOption(
              icon: Icons.wb_sunny_outlined,
              title: 'Tomorrow',
              subtitle:
                  _formatDate(DateTime.now().add(const Duration(days: 1))),
              isSelected: _isScheduledRide && _isTomorrow(),
              onTap: () {
                setState(() {
                  _isScheduledRide = true;
                  _scheduledDate = DateTime.now().add(const Duration(days: 1));
                });
                _pickTime();
              },
            ),

            _buildScheduleOption(
              icon: Icons.calendar_month,
              title: 'Schedule for Later',
              subtitle: _isScheduledRide && !_isTomorrow()
                  ? '${_formatDate(_scheduledDate)} at ${_formatTime(_scheduledTime)}'
                  : 'Pick a date and time',
              isSelected: _isScheduledRide && !_isTomorrow(),
              onTap: () async {
                await _pickDate();
                if (_isScheduledRide) {
                  await _pickTime();
                }
              },
            ),

            // Show selected schedule summary
            if (_isScheduledRide) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.secondary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scheduled Pickup',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${_formatDate(_scheduledDate)} at ${_formatTime(_scheduledTime)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _pickDate();
                        if (_isScheduledRide) {
                          await _pickTime();
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ScaleButton(
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: isSelected ? Colors.black : AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate.isAfter(now) ? _scheduledDate : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _isScheduledRide = true;
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  bool _isTomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return _scheduledDate.year == tomorrow.year &&
        _scheduledDate.month == tomorrow.month &&
        _scheduledDate.day == tomorrow.day;
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEE, MMM d').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  Widget _buildServiceStep() {
    // Auto-calculate driving time from route (with buffer for traffic)
    final routeDurationHours = _routeInfo != null
        ? ((_routeInfo!.durationMinutes * 1.3) / 60)
            .ceil() // 30% traffic buffer
        : 2;

    // For round trip, double the driving time
    final baseDrivingHours =
        _tripType == 'round_trip' ? routeDurationHours * 2 : routeDurationHours;

    // Enforce minimum booking
    final minHours = baseDrivingHours < DrivoPricing.minimumBookingHours
        ? DrivoPricing.minimumBookingHours
        : baseDrivingHours;

    // Update state if needed
    if (_estimatedDrivingHours < minHours) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _estimatedDrivingHours = minHours);
      });
    }

    final drivingCharge =
        _estimatedDrivingHours * DrivoPricing.drivingRatePerHour;
    final waitingCharge =
        _declaredWaitingHours * DrivoPricing.waitingRatePerHour;
    final subtotal = drivingCharge + waitingCharge;

    return Column(
      children: [
        // Compact header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          color: Colors.black,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Duration & Pricing',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '₹${DrivoPricing.drivingRatePerHour.toInt()}/hr',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driving time - auto calculated, read-only display
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Driving',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Auto',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '₹${drivingCharge.toInt()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Time display with route info
                      Row(
                        children: [
                          _buildTimeChip(
                            '$_estimatedDrivingHours',
                            'hrs',
                            isSelected: true,
                          ),
                          const SizedBox(width: 12),
                          if (_routeInfo != null)
                            Expanded(
                              child: Text(
                                '${_routeInfo!.distanceKm.toStringAsFixed(0)} km${_tripType == 'round_trip' ? ' × 2' : ''} • includes traffic buffer',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Add extra time
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Need more time?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          _buildCompactAdjuster(
                            value: _estimatedDrivingHours - minHours,
                            minValue: 0,
                            maxValue: 8,
                            onDecrement: _estimatedDrivingHours > minHours
                                ? () => setState(() => _estimatedDrivingHours--)
                                : null,
                            onIncrement: _estimatedDrivingHours < 12
                                ? () => setState(() => _estimatedDrivingHours++)
                                : null,
                            suffix: 'extra',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Waiting time selector
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _declaredWaitingHours > 0
                          ? AppColors.primary.withOpacity(0.4)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Waiting',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${DrivoPricing.waitingRatePerHour.toInt()}/hr',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _declaredWaitingHours > 0
                                ? '₹${waitingCharge.toInt()}'
                                : 'None',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.5,
                              color: _declaredWaitingHours > 0
                                  ? Colors.black
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Quick select buttons
                      Row(
                        children: [
                          _buildQuickWaitOption(0, 'None'),
                          const SizedBox(width: 8),
                          _buildQuickWaitOption(1, '1 hr'),
                          const SizedBox(width: 8),
                          _buildQuickWaitOption(2, '2 hrs'),
                          const SizedBox(width: 8),
                          _buildQuickWaitOption(3, '3 hrs'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Over-wait note
                if (_declaredWaitingHours > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 2),
                    child: Text(
                      'Extra waiting: ₹${DrivoPricing.overWaitPenaltyPerHour.toInt()}/hr',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Total section - compact
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated fare',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+ return fee if applicable',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${subtotal.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            letterSpacing: -0.5,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChip(String value, String unit, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isSelected ? Colors.black : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAdjuster({
    required int value,
    required int minValue,
    required int maxValue,
    VoidCallback? onDecrement,
    VoidCallback? onIncrement,
    String suffix = '',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                '−',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      onDecrement != null ? Colors.black : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              value == 0 ? '0' : '+$value $suffix',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: value > 0 ? Colors.black : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                '+',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      onIncrement != null ? Colors.black : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickWaitOption(int hours, String label) {
    final isSelected = _declaredWaitingHours == hours;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _declaredWaitingHours = hours),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
              color: isSelected ? Colors.black : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildPricingInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTimeButton({required IconData icon, VoidCallback? onTap}) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isEnabled ? Colors.grey.shade100 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEnabled ? Colors.grey.shade300 : Colors.grey.shade200,
          ),
        ),
        child: Icon(
          icon,
          color: isEnabled ? Colors.black : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      ],
    );
  }

  // Legacy method kept for compatibility
  Widget _buildServiceOption(String title, String price, IconData icon) {
    final isSelected = _selectedService == title;
    return ScaleButton(
      onPressed: () => setState(() => _selectedService = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: isSelected ? Colors.black : AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(price, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ==================== RETURN MODEL STEP ====================

  /// Calculate return fee based on distance
  double _calculateReturnFee() {
    if (_pickupLocation == null || _destinationLocation == null) return 0;

    const Distance distance = Distance();
    final km = distance.as(
        LengthUnit.Kilometer, _pickupLocation!, _destinationLocation!);

    // For round trip: Check if return destination matches pickup
    if (_tripType == 'round_trip') {
      // Get return destination from return stops
      final returnDestination =
          _returnStops.isNotEmpty && _returnStops.last.latitude != 0
              ? LatLng(_returnStops.last.latitude, _returnStops.last.longitude)
              : _pickupLocation;

      // If return destination is same as pickup, no fee
      final returnDistance =
          distance.as(LengthUnit.Meter, _pickupLocation!, returnDestination!);
      if (returnDistance < 100) {
        return 0; // Same location, no fee
      }

      // Different return destination, calculate fee
      final returnKm = distance.as(
          LengthUnit.Kilometer, _pickupLocation!, returnDestination);
      return returnKm * 15; // ₹15 per km
    }

    // For one way: Always charge return fee based on pickup to destination distance
    return km * 15; // ₹15 per km
  }

  Widget _buildReturnModelStep() {
    // Calculate return fee
    final returnFee = _calculateReturnFee();

    // Get return destination for round trip
    LatLng? returnDestination;
    if (_tripType == 'round_trip' &&
        _returnStops.isNotEmpty &&
        _returnStops.last.latitude != 0) {
      returnDestination =
          LatLng(_returnStops.last.latitude, _returnStops.last.longitude);
    } else {
      returnDestination = _pickupLocation;
    }

    return ReturnModeSelector(
      tripType: _tripType,
      outwardPickup: _pickupLocation,
      outwardDestination: _destinationLocation,
      returnPickup: _destinationLocation,
      returnDestination: returnDestination,
      selectedModel: _selectedReturnModel,
      onModelSelected: (model) {
        setState(() {
          _selectedReturnModel = model;
        });
      },
      estimatedReturnDuration: _routeInfo?.durationMinutes.toDouble(),
      calculatedReturnFee: returnFee,
    );
  }

  Widget _buildConfirmStep() {
    // Enterprise pricing calculation
    final fareBreakdown = FareBreakdown.estimate(
      drivingHours: _estimatedDrivingHours.toDouble(),
      waitingHours: _declaredWaitingHours.toDouble(),
      returnDistanceKm: _calculateReturnDistanceKm(),
      hasReturnFee: _tripType == 'one_way' || !_isReturnToSameLocation(),
    );

    final returnFee = _calculateReturnFee();
    final totalFare = fareBreakdown.subtotal + returnFee;

    return Column(
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
                'Confirm Booking',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review your trip details',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Trip route card
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pickup',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      _pickupAddress ?? 'Current Location',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 21),
                          child:
                              Divider(height: 1, color: Colors.grey.shade200),
                        ),
                        // Destination
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: Colors.red, size: 14),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Destination',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      _destinationAddress ?? 'Not selected',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Trip details row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDetailChip(
                          icon: Icons.drive_eta,
                          label: '$_estimatedDrivingHours hrs',
                          sublabel: 'Driving',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailChip(
                          icon: Icons.hourglass_empty,
                          label: _declaredWaitingHours > 0
                              ? '$_declaredWaitingHours hrs'
                              : 'None',
                          sublabel: 'Waiting',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailChip(
                          icon: Icons.sync,
                          label:
                              _tripType == 'round_trip' ? 'Round' : 'One Way',
                          sublabel: 'Trip',
                        ),
                      ),
                    ],
                  ),
                ),

                // Car type if selected
                if (_selectedCarType != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car,
                              size: 20, color: Colors.grey.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_selectedCarType!.displayName} • ${_selectedCarType!.transmission.displayName}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Price breakdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Price Breakdown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _buildPriceRow(
                              'Driving Time',
                              '$_estimatedDrivingHours hrs × ₹${DrivoPricing.drivingRatePerHour.toInt()}',
                              '₹${fareBreakdown.drivingCharge.toInt()}',
                            ),
                            Divider(height: 1, color: Colors.grey.shade100),
                            if (_declaredWaitingHours > 0) ...[
                              _buildPriceRow(
                                'Waiting Time',
                                '$_declaredWaitingHours hrs × ₹${DrivoPricing.waitingRatePerHour.toInt()}',
                                '₹${fareBreakdown.waitingCharge.toInt()}',
                              ),
                              Divider(height: 1, color: Colors.grey.shade100),
                            ],
                            if (returnFee > 0) ...[
                              _buildPriceRow(
                                'Driver Return',
                                '${_calculateReturnDistanceKm().toStringAsFixed(1)} km × ₹15',
                                '₹${returnFee.toInt()}',
                                isSubtle: true,
                              ),
                              Divider(height: 1, color: Colors.grey.shade100),
                            ],
                            // Total
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(7),
                                  bottomRight: Radius.circular(7),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '₹${totalFare.toInt()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Payment note
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Payment will be collected at the end of trip. Any additional waiting will be charged at ₹${DrivoPricing.overWaitPenaltyPerHour.toInt()}/hr.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required String sublabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            sublabel,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String detail, String amount,
      {bool isSubtle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isSubtle ? Colors.grey.shade700 : Colors.black,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isSubtle ? Colors.grey.shade700 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateReturnDistanceKm() {
    if (_pickupLocation == null || _destinationLocation == null) return 0;
    const Distance distance = Distance();
    return distance.as(
        LengthUnit.Kilometer, _pickupLocation!, _destinationLocation!);
  }

  bool _isReturnToSameLocation() {
    if (_pickupLocation == null) return true;
    if (_returnStops.isEmpty || _returnStops.last.latitude == 0) return true;

    final returnDest =
        LatLng(_returnStops.last.latitude, _returnStops.last.longitude);
    const Distance distance = Distance();
    final meters = distance.as(LengthUnit.Meter, _pickupLocation!, returnDest);
    return meters < 100;
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingView() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 6,
              ),
            ),
            const SizedBox(height: 32),
            Text('Finding a driver nearby...',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('This usually takes 30-60 seconds',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverFoundView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Found!')),
      body: FadeSlideTransition(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person, size: 50, color: Colors.black),
              ),
              const SizedBox(height: 16),
              Text(_assignedDriver!.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(
                '${_assignedDriver!.carModel} • ${_assignedDriver!.plateNumber}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  Text(
                    _assignedDriver!.rating.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/trip/live'),
                  child: const Text('Start Trip'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
