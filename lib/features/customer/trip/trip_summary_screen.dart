import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/return_models.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data - in real app, these come from trip state
    const returnModel = ReturnModel.roundTrip;
    const tripDuration = 45;
    const returnDuration = 20;
    const totalDuration = 65;
    const tripCost = 450.0;
    const returnFee = 0.0; // 0 for round trip since included
    const totalFare = 550.0;
    const driverName = 'Rajesh Kumar';
    const driverRating = 4.8;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Icon
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Trip Completed',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                returnModel == ReturnModel.roundTrip
                    ? 'Your car has been safely returned!'
                    : 'Hope you had a great ride!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Return Model Badge
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getReturnModelColor(returnModel).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getReturnModelColor(returnModel).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getReturnModelIcon(returnModel),
                        size: 18,
                        color: _getReturnModelColor(returnModel),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        returnModel.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _getReturnModelColor(returnModel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Trip Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip Details',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.timer,
                        'Customer Journey',
                        '$tripDuration mins',
                      ),
                      if (returnModel == ReturnModel.roundTrip) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        _buildDetailRow(
                          Icons.sync,
                          'Return Journey',
                          '$returnDuration mins',
                          iconColor: AppColors.info,
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      _buildDetailRow(
                        Icons.access_time,
                        'Total Duration',
                        '$totalDuration mins',
                        valueStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fare Breakdown Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fare Breakdown',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),
                      _buildFareRow(
                          'Trip Cost', '₹${tripCost.toStringAsFixed(0)}'),
                      if (returnModel == ReturnModel.roundTrip) ...[
                        const SizedBox(height: 12),
                        _buildFareRow(
                          'Return (Included)',
                          'Included',
                          valueColor: AppColors.success,
                        ),
                      ] else if (returnFee > 0) ...[
                        const SizedBox(height: 12),
                        _buildFareRow(
                          'Return Fee',
                          '+₹${returnFee.toStringAsFixed(0)}',
                          valueColor: AppColors.warning,
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '₹${totalFare.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Rate Driver Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Rate Your Driver',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.surface,
                            child: Icon(Icons.person,
                                size: 32, color: AppColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.star,
                                      color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    driverRating.toString(),
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              // Handle rating
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                index < 4 ? Icons.star : Icons.star_border,
                                size: 40,
                                color: index < 4 ? Colors.amber : Colors.grey,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Quick feedback chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildFeedbackChip('Safe driving'),
                          _buildFeedbackChip('Punctual'),
                          _buildFeedbackChip('Polite'),
                          _buildFeedbackChip('Clean car'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Done Button
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Done'),
              ),
              const SizedBox(height: 16),

              // Help link
              TextButton(
                onPressed: () {
                  // Open help
                },
                child: Text(
                  'Need help with this trip?',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
    TextStyle? valueStyle,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget _buildFareRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackChip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {},
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.border),
    );
  }

  Color _getReturnModelColor(ReturnModel model) {
    switch (model) {
      case ReturnModel.roundTrip:
        return AppColors.success;
      case ReturnModel.platformReturn:
        return AppColors.warning;
      case ReturnModel.zoneBased:
        return AppColors.info;
    }
  }

  IconData _getReturnModelIcon(ReturnModel model) {
    switch (model) {
      case ReturnModel.roundTrip:
        return Icons.sync;
      case ReturnModel.platformReturn:
        return Icons.person_pin_circle;
      case ReturnModel.zoneBased:
        return Icons.hub;
    }
  }
}
