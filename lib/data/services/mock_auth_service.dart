import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// Model
class User {
  final String id;
  final String phoneNumber;
  final String name;

  User({required this.id, required this.phoneNumber, required this.name});
}

// Service - Works with Supabase test phone credentials
class MockAuthService {
  // Test credentials configured in Supabase
  static const _testPhone = '9176101672';
  static const _testOtp = '123456';

  Future<void> sendOtp(String phoneNumber) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 500));
    // In production, this would trigger actual SMS via Supabase
  }

  Future<User> verifyOtp(String phoneNumber, String otp) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Clean phone number for comparison
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final lastTenDigits = cleanPhone.length >= 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;

    // Accept test credentials OR hardcoded test OTP
    if ((lastTenDigits == _testPhone && otp == _testOtp) || otp == '123456') {
      return User(
        id: const Uuid().v4(),
        phoneNumber: phoneNumber,
        name: 'Test User',
      );
    } else {
      throw Exception('Invalid OTP');
    }
  }
}

// Provider
final authServiceProvider = Provider<MockAuthService>((ref) {
  return MockAuthService();
});

// State (Simple User State for MVP)
final userProvider = StateProvider<User?>((ref) => null);
