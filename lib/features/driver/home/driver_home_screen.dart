import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isOnline = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Switch(
            value: _isOnline,
            onChanged: (val) {
              setState(() => _isOnline = val);
              if (val) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('You are now Online. Waiting for jobs...')),
                );
              }
            },
            activeColor: AppColors.secondary,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16, left: 8),
            child: Center(
                child: Text('Online',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          // Debug Button
          IconButton(
            icon: const Icon(Icons.add_alert),
            onPressed: () {
              // Simulate Job
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('New Job Request'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Pickup: Indiranagar'),
                      Text('Fare: ₹500'),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Reject')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/driver/trip');
                      },
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // KYC Status Banner
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KYC Verified',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.success)),
                        const Text('Your documents are verified',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: AppColors.success),
                ],
              ),
            ),
            Card(
              color: AppColors.primary,
              child: InkWell(
                onTap: () => context.push('/driver/earnings'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Today\'s Earnings',
                              style: TextStyle(color: Colors.black87)),
                          Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.black54),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('₹2,450',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                      const Divider(color: Colors.black26, height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('Trips', '6'),
                          _buildStat('Hours', '7.5'),
                          _buildStat('Rating', '4.9'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recent Activity / Mock List
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Trips',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            _buildTripItem('Indiranagar -> Koramangala', '₹250', 'Completed'),
            _buildTripItem('MG Road -> Whitefield', '₹550', 'Completed'),
            _buildTripItem('HSR Layout -> Airport', '₹1100', 'Cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildTripItem(String route, String price, String status) {
    Color statusColor =
        status == 'Completed' ? AppColors.success : AppColors.error;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.history, color: AppColors.primary),
        ),
        title: Text(route, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle:
            Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
        trailing: Text(price,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
