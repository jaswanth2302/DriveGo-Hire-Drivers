import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/mock_auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider); // Uncommented
      await authService.requestOtp(phone); // Uncommented

      // Simulate network delay for now - Removed
      // await Future.delayed(const Duration(seconds: 1)); - Removed

      if (mounted) {
        context.push('/otp', extra: phone);
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo or Icon placeholder
              const Icon(
                Icons.directions_car_filled_rounded,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.loginTitle,
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.loginSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Phone Input
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: AppStrings.phoneHint,
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 24),

              // Continue Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text(AppStrings.continueText),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/driver/login'),
                child: const Text('Partner Login'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
