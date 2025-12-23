import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client singleton
class SupabaseService {
  static SupabaseClient? _client;
  static bool _initialized = false;

  /// Initialize Supabase with credentials from .env
  static Future<void> initialize() async {
    if (_initialized) return;

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception(
          'SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env file');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: dotenv.env['DEBUG_MODE'] == 'true',
    );

    _client = Supabase.instance.client;
    _initialized = true;
  }

  /// Get Supabase client instance
  static SupabaseClient get client {
    if (!_initialized || _client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Check if user is authenticated
  static bool get isAuthenticated => client.auth.currentUser != null;

  /// Get current user
  static User? get currentUser => client.auth.currentUser;

  /// Get current session
  static Session? get currentSession => client.auth.currentSession;
}

// Riverpod providers for Supabase

/// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});

/// Provider for current user (reactive)
final currentUserProvider = StreamProvider<User?>((ref) {
  return SupabaseService.client.auth.onAuthStateChange.map((event) {
    return event.session?.user;
  });
});

/// Provider for auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.client.auth.onAuthStateChange;
});

// ==================== TABLE REFERENCES ====================
// Easy access to Supabase tables

extension SupabaseTableExtensions on SupabaseClient {
  // Core tables (linked to auth.users)
  SupabaseQueryBuilder get profiles => from('profiles');
  SupabaseQueryBuilder get driverProfiles => from('driver_profiles');
  SupabaseQueryBuilder get bookings => from('bookings');
  SupabaseQueryBuilder get carTypes => from('car_types');

  // Booking related
  SupabaseQueryBuilder get tripStops => from('trip_stops');
  SupabaseQueryBuilder get tripReturnInfo => from('trip_return_info');
  SupabaseQueryBuilder get returnTasks => from('return_tasks');
  SupabaseQueryBuilder get liveBilling => from('live_billing');

  // Payments
  SupabaseQueryBuilder get payments => from('payments');
  SupabaseQueryBuilder get savedPaymentMethods => from('saved_payment_methods');
  SupabaseQueryBuilder get walletTransactions => from('wallet_transactions');

  // Locations & tracking
  SupabaseQueryBuilder get savedLocations => from('saved_locations');
  SupabaseQueryBuilder get driverLocationHistory =>
      from('driver_location_history');
  SupabaseQueryBuilder get tripTrail => from('trip_trail');
  SupabaseQueryBuilder get serviceZones => from('service_zones');

  // Safety
  SupabaseQueryBuilder get safetyAlerts => from('safety_alerts');
  SupabaseQueryBuilder get geofenceEvents => from('geofence_events');
  SupabaseQueryBuilder get emergencyContacts => from('emergency_contacts');

  // Ratings & feedback
  SupabaseQueryBuilder get ratings => from('ratings');
  SupabaseQueryBuilder get supportTickets => from('support_tickets');

  // Driver management
  SupabaseQueryBuilder get driverEarnings => from('driver_earnings');
  SupabaseQueryBuilder get driverBonuses => from('driver_bonuses');
  SupabaseQueryBuilder get driverAvailability => from('driver_availability');
  SupabaseQueryBuilder get driverTimeOff => from('driver_time_off');

  // Promos & referrals
  SupabaseQueryBuilder get promoCodes => from('promo_codes');
  SupabaseQueryBuilder get promoUsage => from('promo_usage');
  SupabaseQueryBuilder get referrals => from('referrals');

  // Notifications
  SupabaseQueryBuilder get notifications => from('notifications');
  SupabaseQueryBuilder get pushTokens => from('push_tokens');

  // Config
  SupabaseQueryBuilder get appConfig => from('app_config');
  SupabaseQueryBuilder get cityReturnFees => from('city_return_fees');

  // KYC
  SupabaseQueryBuilder get userKycDocuments => from('user_kyc_documents');
  SupabaseQueryBuilder get driverKycDocuments => from('driver_kyc_documents');

  // Long trips
  SupabaseQueryBuilder get longTripBookings => from('long_trip_bookings');
}
