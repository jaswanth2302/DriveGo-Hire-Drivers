import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';

// Tab screens
import 'customer/home/home_screen.dart';
import 'ride/ride_home_screen.dart';
import 'driver/driver_trips_screen.dart';
import 'rental/rental_home_screen.dart';
import 'customer/profile/profile_screen.dart';

/// Global key to access MainShell state from anywhere
final mainShellKey = GlobalKey<MainShellState>();

/// Provider to switch tabs from anywhere
final tabIndexProvider = StateProvider<int>((ref) => 0);

/// Main Shell with 5-Tab Bottom Navigation
/// Home | Ride | Driver Trips | Car Rental | Profile
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => MainShellState();
}

class MainShellState extends ConsumerState<MainShell> {
  // Tab screens
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomeScreen(onNavigateToTab: switchToTab),
      const RideHomeScreen(),
      const DriverTripsScreen(),
      const RentalHomeScreen(),
      const ProfileScreen(),
    ];
  }

  /// Public method to switch tabs from anywhere
  void switchToTab(int index) {
    ref.read(tabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tabIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, 'Home', Icons.home_outlined, Icons.home),
                _buildNavItem(
                    1, 'Ride', Icons.local_taxi_outlined, Icons.local_taxi),
                _buildNavItem(2, 'Driver', Icons.person_pin_circle_outlined,
                    Icons.person_pin_circle),
                _buildNavItem(3, 'Rental', Icons.directions_car_outlined,
                    Icons.directions_car),
                _buildNavItem(4, 'Profile', Icons.person_outline, Icons.person),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, String label, IconData icon, IconData activeIcon) {
    final currentIndex = ref.watch(tabIndexProvider);
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => switchToTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? Colors.black : Colors.grey.shade600,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
