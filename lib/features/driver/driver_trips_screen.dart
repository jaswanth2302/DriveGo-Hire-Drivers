import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

/// Driver Trips Screen - Main hub for hiring drivers
/// Short trips + Long trips (outstation)
class DriverTripsScreen extends StatelessWidget {
  const DriverTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              color: Colors.black,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hire a Driver',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Professional drivers for your car',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '₹199/hr',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
                    // Main trip options
                    Row(
                      children: [
                        Expanded(
                          child: _buildTripOptionCard(
                            context,
                            title: 'City Trip',
                            subtitle: 'Within city',
                            features: [
                              'Hourly billing',
                              'Min 2 hrs',
                              'Round trip'
                            ],
                            price: 'From ₹398',
                            color: AppColors.primary,
                            onTap: () => context.push('/booking'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTripOptionCard(
                            context,
                            title: 'Long Trip',
                            subtitle: 'Outstation',
                            features: [
                              'Multi-day',
                              'Stay included',
                              'Round trip'
                            ],
                            price: 'Custom',
                            color: Colors.blue.shade100,
                            isNew: true,
                            onTap: () => context.push('/long-trip'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick book section
                    const Text(
                      'Quick Book',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildQuickBookCard(context),

                    const SizedBox(height: 24),

                    // Recent Trips
                    Row(
                      children: [
                        const Text(
                          'Your Trips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push('/profile/past-trips'),
                          child: Text(
                            'View all',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Recent trips list
                    _buildRecentTripItem(
                      pickup: 'Indiranagar Metro',
                      drop: 'Bangalore Airport',
                      date: 'Today, 2:30 PM',
                      status: 'Upcoming',
                      statusColor: Colors.blue,
                    ),
                    _buildRecentTripItem(
                      pickup: 'HSR Layout',
                      drop: 'Whitefield',
                      date: 'Dec 20, 10:00 AM',
                      status: 'Completed',
                      statusColor: Colors.green,
                    ),
                    _buildRecentTripItem(
                      pickup: 'Koramangala',
                      drop: 'Electronic City',
                      date: 'Dec 18, 6:30 PM',
                      status: 'Completed',
                      statusColor: Colors.green,
                    ),

                    const SizedBox(height: 24),

                    // How it works
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How it works',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildHowItWorksStep(
                              '1', 'Enter pickup & destination'),
                          _buildHowItWorksStep(
                              '2', 'Select duration & waiting time'),
                          _buildHowItWorksStep(
                              '3', 'Driver arrives at your location'),
                          _buildHowItWorksStep(
                              '4', 'Pay after trip completion'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> features,
    required String price,
    required Color color,
    required VoidCallback onTap,
    bool isNew = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isNew ? Icons.flight_takeoff : Icons.drive_eta,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
                if (isNew) ...[
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 12, color: Colors.green.shade600),
                      const SizedBox(width: 6),
                      Text(
                        f,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickBookCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/booking'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need a driver now?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Book instantly • Driver in 15 mins',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTripItem({
    required String pickup,
    required String drop,
    required String date,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 20,
                color: Colors.grey.shade300,
              ),
              Icon(Icons.location_on, size: 14, color: Colors.red.shade400),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickup,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  drop,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                date,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
