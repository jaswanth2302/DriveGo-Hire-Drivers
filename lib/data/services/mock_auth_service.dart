import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// Model
class User {
  final String id;
  final String phoneNumber;
  final String name;

  User({required this.id, required this.phoneNumber, required this.name});
}

// Service
class MockAuthService {
  Future<void> requestOtp(String phoneNumber) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    // In a real app, this would trigger SMS.
    // Here we just accept any number.
  }

  Future<User> verifyOtp(String phoneNumber, String otp) async {
    await Future.delayed(const Duration(seconds: 1));
    if (otp == '1234') {
      // Mock OTP
      return User(
        id: const Uuid().v4(),
        phoneNumber: phoneNumber,
        name: 'Demo User',
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
