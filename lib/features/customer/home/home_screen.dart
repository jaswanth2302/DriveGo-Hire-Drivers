import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/geocoding_service.dart';

// Provider for current address
final currentAddressProvider = FutureProvider<String>((ref) async {
  try {
    final locationService = ref.read(locationServiceProvider);
    final location = await locationService.getCurrentLocation();
    final geocoding = GeocodingService();
    final address = await geocoding.getAddressFromCoordinates(
      location.latitude,
      location.longitude,
    );
    return address;
  } catch (e) {
    return 'Bangalore, Karnataka';
  }
});

class HomeScreen extends ConsumerWidget {
  final void Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(currentLocationProvider);
    final addressAsync = ref.watch(currentAddressProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          // Map Layer - Full screen
          locationAsync.when(
            data: (location) => FlutterMap(
              options: MapOptions(
                initialCenter: location,
                initialZoom: 16.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.drivo.app',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: location,
                      radius: 40,
                      color: AppColors.primary.withOpacity(0.15),
                      borderColor: AppColors.primary.withOpacity(0.3),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: location,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.black, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (_, __) => Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.location_off, size: 48, color: Colors.grey),
              ),
            ),
          ),

          // Top address bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Current Location',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          addressAsync.when(
                            data: (address) => Text(
                              address,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            loading: () => Text(
                              'Getting location...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            error: (_, __) => const Text(
                              'Bangalore, Karnataka',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
          ),

          // Bottom sheet with services
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.42,
            maxChildSize: 0.75,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Search bar - "Where are you going?"
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: GestureDetector(
                        onTap: () => context.push('/booking'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search,
                                  color: Colors.grey.shade600, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                'Where are you going?',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Book a Trip button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.push('/booking'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Book a Trip',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Services Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Our Services',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),

                    // Service cards - horizontal scroll
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _buildServiceCard(
                            context,
                            title: 'Hire Driver',
                            subtitle: 'For your car',
                            color: AppColors.primary,
                            onTap: () {
                              onNavigateToTab?.call(2); // Driver tab
                            },
                          ),
                          _buildServiceCard(
                            context,
                            title: 'Book Ride',
                            subtitle: 'Cabs & Bikes',
                            color: Colors.blue.shade100,
                            onTap: () {
                              onNavigateToTab?.call(1); // Ride tab
                            },
                          ),
                          _buildServiceCard(
                            context,
                            title: 'Long Trip',
                            subtitle: 'Outstation',
                            color: Colors.green.shade100,
                            onTap: () => context.push('/long-trip'),
                          ),
                          _buildServiceCard(
                            context,
                            title: 'Rent Car',
                            subtitle: 'P2P Rental',
                            color: Colors.orange.shade100,
                            onTap: () {
                              onNavigateToTab?.call(3); // Rental tab
                            },
                          ),
                        ],
                      ),
                    ),

                    // Recent Driver Trips Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Recent Driver Trips',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'See all',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Recent trips - horizontal scroll
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _buildRecentTripCard(
                            context,
                            pickup: 'Indiranagar',
                            drop: 'Koramangala',
                            date: 'Dec 20',
                            duration: '45 min',
                            status: 'Completed',
                          ),
                          _buildRecentTripCard(
                            context,
                            pickup: 'HSR Layout',
                            drop: 'Whitefield',
                            date: 'Dec 18',
                            duration: '1h 20m',
                            status: 'Completed',
                          ),
                          _buildRecentTripCard(
                            context,
                            pickup: 'MG Road',
                            drop: 'Electronic City',
                            date: 'Dec 15',
                            duration: '55 min',
                            status: 'Completed',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTripCard(
    BuildContext context, {
    required String pickup,
    required String drop,
    required String date,
    required String duration,
    required String status,
  }) {
    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pickup,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(
              width: 2,
              height: 10,
              color: Colors.grey.shade300,
            ),
          ),
          Row(
            children: [
              Icon(Icons.location_on, size: 10, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  drop,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Bottom row
          Row(
            children: [
              Text(
                '$date • $duration',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Rebook',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
