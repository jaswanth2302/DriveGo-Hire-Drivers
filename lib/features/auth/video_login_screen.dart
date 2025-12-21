import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/video_background.dart';

/// Login screen with smooth background video.
///
/// Uses the VideoBackground widget for:
/// - Muted autoplay video
/// - Seamless looping
/// - Lifecycle-aware playback
/// - Dark overlay for text readability
class VideoLoginScreen extends StatelessWidget {
  const VideoLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoBackground(
        assetPath: 'assets/IMG_2816.mp4',
        overlayOpacity: 0.3, // 30% dark overlay for readability
        overlayColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo & Branding
              _buildBranding(context),

              const Spacer(flex: 3),

              // Login Form
              _buildLoginForm(context),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranding(BuildContext context) {
    return Column(
      children: [
        // Logo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_car,
            size: 48,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 24),

        // App Name
        const Text(
          'DRIVO',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 8),

        // Tagline
        Text(
          'Your Personal Driver, Anytime',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Phone input
          TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Enter mobile number',
              prefixIcon: const Icon(Icons.phone_android),
              prefixText: '+91 ',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Terms text
          Text(
            'By continuing, you agree to our Terms of Service',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
