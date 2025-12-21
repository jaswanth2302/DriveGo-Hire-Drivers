import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_widgets.dart';

class PastTripsScreen extends StatelessWidget {
  const PastTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Trips'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FadeSlideTransition(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _mockTrips.length,
          itemBuilder: (context, index) {
            final trip = _mockTrips[index];
            return StaggeredListItem(
              index: index,
              child: _TripCard(trip: trip),
            );
          },
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trip['date'],
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Completed',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route
          Row(
            children: [
              Column(
                children: [
                  Icon(Icons.circle, size: 12, color: AppColors.primary),
                  Container(
                    width: 2,
                    height: 30,
                    color: AppColors.border,
                  ),
                  Icon(Icons.location_on, size: 16, color: AppColors.secondary),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip['pickup'],
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      trip['dropoff'],
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surface,
                    child: Icon(Icons.person,
                        size: 18, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    trip['driver'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.star, size: 14, color: AppColors.primary),
                  Text(
                    trip['rating'].toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              Text(
                '₹${trip['fare']}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final List<Map<String, dynamic>> _mockTrips = [
  {
    'date': 'Dec 19, 2024',
    'pickup': 'Indiranagar Metro Station',
    'dropoff': 'Koramangala 5th Block',
    'driver': 'Ramesh K.',
    'rating': 4.8,
    'fare': 550,
  },
  {
    'date': 'Dec 17, 2024',
    'pickup': 'HSR Layout Sector 1',
    'dropoff': 'Electronic City Phase 1',
    'driver': 'Suresh M.',
    'rating': 4.9,
    'fare': 720,
  },
  {
    'date': 'Dec 15, 2024',
    'pickup': 'Whitefield Main Road',
    'dropoff': 'MG Road Metro',
    'driver': 'Arun P.',
    'rating': 4.7,
    'fare': 480,
  },
  {
    'date': 'Dec 12, 2024',
    'pickup': 'JP Nagar 6th Phase',
    'dropoff': 'Bangalore Airport',
    'driver': 'Vijay S.',
    'rating': 5.0,
    'fare': 1250,
  },
];
