import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:drivo/features/auth/login_screen.dart';
import 'package:drivo/features/auth/otp_screen.dart';
import 'package:drivo/features/auth/email_login_screen.dart';
import 'package:drivo/features/main_shell.dart';
import 'package:drivo/features/customer/booking/booking_screen.dart';
import 'package:drivo/features/customer/booking/long_trip_screen.dart';
import 'package:drivo/features/customer/trip/live_trip_screen.dart';
import 'package:drivo/features/customer/trip/trip_summary_screen.dart';
import 'package:drivo/features/driver/auth/driver_login_screen.dart';
import 'package:drivo/features/driver/home/driver_home_screen.dart';
import 'package:drivo/features/driver/trip/driver_trip_screen.dart';
import 'package:drivo/features/splash/splash_screen.dart';
import 'package:drivo/features/customer/profile/profile_screen.dart';
import 'package:drivo/features/customer/profile/past_trips_screen.dart';
import 'package:drivo/features/customer/profile/saved_locations_screen.dart';
import 'package:drivo/features/customer/profile/payment_methods_screen.dart';
import 'package:drivo/features/driver/earnings/earnings_screen.dart';
import 'package:drivo/features/auth/video_login_screen.dart';

// Keys
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/email',
        builder: (context, state) => const EmailLoginScreen(),
      ),
      GoRoute(
        path: '/video-login',
        builder: (context, state) => const VideoLoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phoneNumber: phone);
        },
      ),
      // Main app with 5-tab navigation
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainShell(),
      ),
      // Booking flows (pushed on top of shell)
      GoRoute(
        path: '/booking',
        builder: (context, state) => const BookingScreen(),
      ),
      GoRoute(
        path: '/long-trip',
        builder: (context, state) => const LongTripScreen(),
      ),
      GoRoute(
        path: '/trip/live',
        builder: (context, state) => const LiveTripScreen(),
      ),
      GoRoute(
        path: '/trip/summary',
        builder: (context, state) => const TripSummaryScreen(),
      ),
      // Driver app routes
      GoRoute(
        path: '/driver/login',
        builder: (context, state) => const DriverLoginScreen(),
      ),
      GoRoute(
        path: '/driver/home',
        builder: (context, state) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: '/driver/trip',
        builder: (context, state) => const DriverTripScreen(),
      ),
      GoRoute(
        path: '/driver/earnings',
        builder: (context, state) => const EarningsScreen(),
      ),
      // Profile Routes
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/past-trips',
        builder: (context, state) => const PastTripsScreen(),
      ),
      GoRoute(
        path: '/profile/saved-locations',
        builder: (context, state) => const SavedLocationsScreen(),
      ),
      GoRoute(
        path: '/profile/payment-methods',
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
    ],
  );
}
