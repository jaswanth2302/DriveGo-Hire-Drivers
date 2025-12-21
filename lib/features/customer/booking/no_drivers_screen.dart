import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_widgets.dart';

class NoDriversScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onGoBack;

  const NoDriversScreen({
    super.key,
    required this.onRetry,
    required this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeSlideTransition(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // Animated illustration
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (value * 0.2),
                      child: Opacity(
                        opacity: value,
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.car_crash_outlined,
                            size: 80,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),

                // Title
                Text(
                  'No Drivers Available',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'We couldn\'t find any drivers in your area right now. This might be due to high demand or limited availability.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Suggestions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildSuggestion(
                        context,
                        Icons.schedule,
                        'Try scheduling for later',
                      ),
                      const SizedBox(height: 12),
                      _buildSuggestion(
                        context,
                        Icons.location_on,
                        'Change your pickup location',
                      ),
                      const SizedBox(height: 12),
                      _buildSuggestion(
                        context,
                        Icons.refresh,
                        'Retry in a few minutes',
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Retry button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ),
                const SizedBox(height: 12),

                // Go back button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onGoBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Go Back'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestion(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
