import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/auth_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Real user data
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;

  // Mock KYC status (keep until backend ready)
  String _kycStatus = 'verified'; // pending, in_review, verified, rejected

  // Mock listed cars
  final List<Map<String, dynamic>> _listedCars = [
    {
      'name': 'Maruti Swift',
      'price': 1200,
      'status': 'active',
      'bookings': 5,
      'earnings': 6000,
    },
  ];

  // Mock combined trip history
  final List<Map<String, dynamic>> _tripHistory = [
    {
      'type': 'driver',
      'from': 'Indiranagar',
      'to': 'Airport',
      'date': 'Dec 21',
      'amount': 850,
      'status': 'completed',
    },
    // ... kept mock history for now
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    print('DEBUG: Starting loadProfile');
    final authService = ref.read(authServiceProvider);

    // 1. Instant Fallback to Auth Metadata
    if (authService.currentUser != null) {
      final user = authService.currentUser!;
      setState(() {
        // Initialize with Auth Data first
        _userProfile = {
          'name': user.userMetadata?['name'] ?? 'User',
          'phone': user.phone ?? '',
          'email': user.email ?? '',
          'id': user.id,
        };
      });
    }

    setState(() => _isLoading = true);

    try {
      print('DEBUG: Fetching DB profile');
      // Force timeout after 10 seconds
      final profile = await authService.getUserProfile().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('DEBUG: Timeout fetching profile');
          return null;
        },
      );

      print('DEBUG: Fetched profile: $profile');

      if (mounted) {
        setState(() {
          if (profile != null) {
            _userProfile = profile;
            if (profile['kyc_status'] != null) {
              _kycStatus = profile['kyc_status'].toString();
            }
          }
        });
      }
    } catch (e) {
      print('DEBUG: Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _userProfile?['name'] as String? ?? 'User';
    final phone = _userProfile?['phone'] as String? ?? 'No Phone';
    final email = _userProfile?['email'] as String? ?? '';
    final photoUrl = _userProfile?['photo_url'] as String?;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_isLoading)
                const LinearProgressIndicator(
                    backgroundColor: Colors.white, color: AppColors.primary),

              // Header with profile info
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black,
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primary,
                          backgroundImage:
                              photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? const Icon(Icons.person,
                                  size: 36, color: Colors.black)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (phone.isNotEmpty)
                                Text(
                                  phone,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showEditProfile(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // KYC Status
                    _buildKycBanner(),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats
                    _buildQuickStats(),
                    const SizedBox(height: 20),

                    // My Listed Cars Section
                    if (_listedCars.isNotEmpty) ...[
                      _buildSectionHeader('My Listed Cars', onSeeAll: () {}),
                      const SizedBox(height: 10),
                      ..._listedCars.map((car) => _buildListedCarCard(car)),
                      const SizedBox(height: 20),
                    ],

                    // Combined Trip History
                    _buildSectionHeader('Recent Activity',
                        onSeeAll: () => context.push('/profile/past-trips')),
                    const SizedBox(height: 10),
                    ..._tripHistory
                        .take(3)
                        .map((trip) => _buildTripHistoryItem(trip)),
                    const SizedBox(height: 20),

                    // Menu Items
                    _buildMenuItem(
                      icon: Icons.history,
                      title: 'All Trips',
                      subtitle: 'Driver, Rides & Rentals',
                      onTap: () => context.push('/profile/past-trips'),
                    ),
                    _buildMenuItem(
                      icon: Icons.directions_car,
                      title: 'My Cars',
                      subtitle: 'Listed for rental',
                      badge: '${_listedCars.length}',
                      onTap: () => _showMyCars(),
                    ),
                    _buildMenuItem(
                      icon: Icons.location_on_outlined,
                      title: 'Saved Locations',
                      subtitle: 'Home, Work, Favorites',
                      onTap: () => context.push('/profile/saved-locations'),
                    ),
                    _buildMenuItem(
                      icon: Icons.payment_outlined,
                      title: 'Payment Methods',
                      subtitle: 'UPI, Cards, Wallet',
                      onTap: () => context.push('/profile/payment-methods'),
                    ),
                    _buildMenuItem(
                      icon: Icons.verified_user_outlined,
                      title: 'KYC Verification',
                      subtitle: _kycStatus == 'verified'
                          ? 'Verified'
                          : 'Complete your KYC',
                      statusColor: _kycStatus == 'verified'
                          ? Colors.green
                          : Colors.orange,
                      onTap: () => _showKycDetails(),
                    ),
                    _buildMenuItem(
                      icon: Icons.support_agent_outlined,
                      title: 'Help & Support',
                      subtitle: 'FAQ, Contact us',
                      onTap: () {},
                    ),
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Notifications, Privacy',
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            // Show loading indicator on button? Or just await
                            await ref.read(authServiceProvider).signOut();
                          } catch (e) {
                            print('Logout error: $e');
                          } finally {
                            if (context.mounted) {
                              context.go('/login');
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Logout'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKycBanner() {
    Color bgColor;
    Color textColor;
    IconData icon;
    String text;

    switch (_kycStatus) {
      case 'verified':
        bgColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green.shade300;
        icon = Icons.verified;
        text = 'KYC Verified';
        break;
      case 'pending':
        bgColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orange.shade300;
        icon = Icons.pending;
        text = 'KYC Pending';
        break;
      case 'in_review':
        bgColor = Colors.blue.withOpacity(0.2);
        textColor = Colors.blue.shade300;
        icon = Icons.hourglass_top;
        text = 'KYC In Review';
        break;
      default:
        bgColor = Colors.red.withOpacity(0.2);
        textColor = Colors.red.shade300;
        icon = Icons.error_outline;
        text = 'KYC Rejected';
    }

    return GestureDetector(
      onTap: () => _showKycDetails(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildStatItem('24', 'Trips'),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _buildStatItem('₹15,400', 'Spent'),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _buildStatItem('₹6,000', 'Earned'),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          _buildStatItem('4.8', 'Rating'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'See all',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListedCarCard(Map<String, dynamic> car) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_car, color: Colors.black54),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${car['bookings']} bookings • ₹${car['earnings']} earned',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Active',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripHistoryItem(Map<String, dynamic> trip) {
    IconData icon;
    Color iconColor;
    String title;
    String subtitle;

    switch (trip['type']) {
      case 'driver':
        icon = Icons.person_pin_circle;
        iconColor = AppColors.primary;
        title = '${trip['from']} → ${trip['to']}';
        subtitle = 'Driver Hire • ${trip['date']}';
        break;
      case 'ride':
        icon = Icons.local_taxi;
        iconColor = Colors.blue;
        title = '${trip['from']} → ${trip['to']}';
        subtitle = 'Ride • ${trip['date']}';
        break;
      case 'rental':
        icon = Icons.directions_car;
        iconColor = Colors.orange;
        title = '${trip['car']} (${trip['days']} days)';
        subtitle = 'Rental • ${trip['date']}';
        break;
      default:
        icon = Icons.trip_origin;
        iconColor = Colors.grey;
        title = 'Trip';
        subtitle = trip['date'] as String;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${trip['amount']}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    Color? statusColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      if (statusColor != null) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  void _showEditProfile() {
    final name = _userProfile?['name'] as String? ?? '';
    final email = _userProfile?['email'] as String? ?? '';
    final nameController = TextEditingController(text: name);
    final emailController = TextEditingController(text: email);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: 'Changing email will require verification',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          final newEmail = emailController.text.trim();

                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Name cannot be empty')),
                            );
                            return;
                          }

                          setSheetState(() => isSaving = true);

                          try {
                            await ref
                                .read(authServiceProvider)
                                .updateUserProfile(
                                  name: newName,
                                  email: newEmail,
                                );

                            if (mounted) {
                              Navigator.pop(context); // Close sheet
                              _loadProfile(); // Refresh UI
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Profile updated successfully')),
                              );
                            }
                          } catch (e) {
                            setSheetState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showKycDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KYC Verification',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),
            _buildKycItem(
                'Aadhaar Card', _kycStatus == 'verified', 'XXXX XXXX 1234'),
            _buildKycItem('PAN Card', _kycStatus == 'verified', 'ABCDE1234F'),
            _buildKycItem(
                'Driving License', _kycStatus == 'verified', 'KA01-1234567890'),
            const SizedBox(height: 20),
            if (_kycStatus != 'verified')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('KYC submission coming soon!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Complete KYC'),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildKycItem(String title, bool verified, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            verified ? Icons.check_circle : Icons.circle_outlined,
            color: verified ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (verified)
                  Text(
                    value,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (verified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Verified',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMyCars() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Listed Cars',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),
            if (_listedCars.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.directions_car,
                        size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'No cars listed yet',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              )
            else
              ..._listedCars.map((car) => _buildListedCarCard(car)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to rental tab
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New Car'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
