import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Authentication service using Supabase Auth
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  // Test user credentials for development
  static const String _testPhone = '9176101672';
  static const String _testOtp = '123456';

  /// Send OTP to phone number
  Future<void> sendOtp(String phoneNumber) async {
    // Ensure phone number is in E.164 format (e.g., +919876543210)
    final formattedPhone = _formatPhoneNumber(phoneNumber);

    // Allow test user to bypass Twilio
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.endsWith(_testPhone)) {
      // Test user - skip actual SMS sending
      return;
    }

    await _client.auth.signInWithOtp(
      phone: formattedPhone,
    );
  }

  /// Verify OTP and sign in
  Future<AuthResponse> verifyOtp(String phoneNumber, String otp) async {
    final formattedPhone = _formatPhoneNumber(phoneNumber);

    // Allow test user to bypass Twilio verification
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.endsWith(_testPhone) && otp == _testOtp) {
      // Test user - use email/password auth as fallback
      // Create a test email from the phone number
      final testEmail = 'test_$_testPhone@drivo.test';

      // First try to sign in (user might exist)
      try {
        return await _client.auth.signInWithPassword(
          email: testEmail,
          password: _testOtp,
        );
      } catch (signinError) {
        // Sign up the test user if sign in fails
        try {
          final response = await _client.auth.signUp(
            email: testEmail,
            password: _testOtp,
            data: {'phone': formattedPhone, 'name': 'Test User'},
          );
          if (response.user != null) {
            return response;
          }
        } catch (signupError) {
          // If signup also fails, try signing in again (race condition check)
          try {
            return await _client.auth.signInWithPassword(
              email: testEmail,
              password: _testOtp,
            );
          } catch (e) {
            throw Exception(
                'Test Auth Failed: Signin: $signinError, Signup: $signupError');
          }
        }
      }

      throw Exception('Test user auth failed');
    }

    return await _client.auth.verifyOTP(
      phone: formattedPhone,
      token: otp,
      type: OtpType.sms,
    );
  }

  // ==================== EMAIL AUTHENTICATION ====================

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
    String? phone,
  }) async {
    return await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      },
    );
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  /// Update password (when logged in)
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // ==================== SESSION MANAGEMENT ====================

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Get user profile from database
  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final response =
        await _client.profiles.select().eq('id', userId).maybeSingle();

    return response;
  }

  /// Create or update user profile
  Future<void> upsertUserProfile({
    required String phone,
    String? name,
    String? email,
    String? photoUrl,
    String cityCode = 'BLR',
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await _client.profiles.upsert({
      'id': userId,
      'phone': phone,
      'name': name,
      'email': email,
      'photo_url': photoUrl,
      'city_code': cityCode,
      // ... existing content ...
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Update user profile (Name, Email) and metadata
  Future<void> updateUserProfile(
      {required String name, required String email}) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // 1. Update Auth Metadata (updates name in auth.users)
    // Note: Changing email sends a confirmation link to the new address
    await _client.auth.updateUser(
      UserAttributes(
        email: email,
        data: {'name': name},
      ),
    );

    // 2. Update DB Profile
    await _client.profiles.update({
      'name': name,
      'email': email, // Store new email even if pending
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Check if user exists in database
  Future<bool> userExists() async {
    final profile = await getUserProfile();
    return profile != null;
  }

  /// Get driver profile from database
  Future<Map<String, dynamic>?> getDriverProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final response =
        await _client.driverProfiles.select().eq('id', userId).maybeSingle();

    return response;
  }

  /// Create or update driver profile
  Future<void> upsertDriverProfile({
    required String phone,
    required String name,
    String? email,
    String? photoUrl,
    String cityCode = 'BLR',
    bool acceptsPlatformReturn = true,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await _client.driverProfiles.upsert({
      'id': userId,
      'phone': phone,
      'name': name,
      'email': email,
      'photo_url': photoUrl,
      'city_code': cityCode,
      'accepts_platform_return': acceptsPlatformReturn,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Check if driver exists in database
  Future<bool> driverExists() async {
    final profile = await getDriverProfile();
    return profile != null;
  }

  /// Format phone number to E.164 format
  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    // If starts with 0, remove it
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // If 10 digits (Indian number without country code), add +91
    if (digits.length == 10) {
      return '+91$digits';
    }

    // If 12 digits starting with 91, add +
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }

    // If already has +, return as is
    if (phone.startsWith('+')) {
      return phone;
    }

    // Default: assume Indian number
    return '+91$digits';
  }
}

// Riverpod provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

// State notifier for auth state
class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    state = AsyncValue.data(_authService.currentUser);
  }

  Future<void> sendOtp(String phoneNumber) async {
    try {
      state = const AsyncValue.loading();
      await _authService.sendOtp(phoneNumber);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> verifyOtp(String phoneNumber, String otp) async {
    try {
      state = const AsyncValue.loading();
      final response = await _authService.verifyOtp(phoneNumber, otp);
      state = AsyncValue.data(response.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authStateNotifierProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<User?>>((ref) {
  return AuthStateNotifier(ref.watch(authServiceProvider));
});
