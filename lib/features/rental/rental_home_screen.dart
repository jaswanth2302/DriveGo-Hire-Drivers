import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Rental Car Model
class RentalCar {
  final String id;
  final String name;
  final String type;
  final String transmission;
  final double pricePerDay;
  final double rating;
  final int trips;
  final String distance;
  final Color imageColor;
  final String owner;
  final List<String> features;

  RentalCar({
    required this.id,
    required this.name,
    required this.type,
    required this.transmission,
    required this.pricePerDay,
    required this.rating,
    required this.trips,
    required this.distance,
    required this.imageColor,
    required this.owner,
    required this.features,
  });
}

/// Car Rental Home Screen - P2P Marketplace
class RentalHomeScreen extends StatefulWidget {
  const RentalHomeScreen({super.key});

  @override
  State<RentalHomeScreen> createState() => _RentalHomeScreenState();
}

class _RentalHomeScreenState extends State<RentalHomeScreen> {
  bool _isRentMode = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Mock car data
  final List<RentalCar> _allCars = [
    RentalCar(
      id: '1',
      name: 'Maruti Swift',
      type: 'Hatchback',
      transmission: 'Manual',
      pricePerDay: 1200,
      rating: 4.8,
      trips: 23,
      distance: '2.3 km',
      imageColor: Colors.red,
      owner: 'Rahul S.',
      features: ['AC', 'Music System', 'Power Steering'],
    ),
    RentalCar(
      id: '2',
      name: 'Hyundai Creta',
      type: 'SUV',
      transmission: 'Automatic',
      pricePerDay: 2500,
      rating: 4.9,
      trips: 45,
      distance: '3.1 km',
      imageColor: Colors.blue,
      owner: 'Priya M.',
      features: ['AC', 'Sunroof', 'Cruise Control', 'Touchscreen'],
    ),
    RentalCar(
      id: '3',
      name: 'Honda City',
      type: 'Sedan',
      transmission: 'Manual',
      pricePerDay: 1800,
      rating: 4.7,
      trips: 31,
      distance: '1.8 km',
      imageColor: Colors.grey,
      owner: 'Amit K.',
      features: ['AC', 'Leather Seats', 'Alloy Wheels'],
    ),
    RentalCar(
      id: '4',
      name: 'Tata Nexon',
      type: 'SUV',
      transmission: 'Manual',
      pricePerDay: 1600,
      rating: 4.6,
      trips: 18,
      distance: '4.2 km',
      imageColor: Colors.green,
      owner: 'Sneha R.',
      features: ['AC', 'Music System', 'Rear Camera'],
    ),
    RentalCar(
      id: '5',
      name: 'Maruti Baleno',
      type: 'Hatchback',
      transmission: 'Automatic',
      pricePerDay: 1400,
      rating: 4.5,
      trips: 12,
      distance: '5.0 km',
      imageColor: Colors.purple,
      owner: 'Vikram J.',
      features: ['AC', 'SmartPlay', 'LED DRLs'],
    ),
    RentalCar(
      id: '6',
      name: 'Toyota Innova',
      type: 'SUV',
      transmission: 'Manual',
      pricePerDay: 3000,
      rating: 4.9,
      trips: 67,
      distance: '2.8 km',
      imageColor: Colors.brown,
      owner: 'Karthik N.',
      features: ['AC', '7 Seater', 'Cruise Control', 'Rear AC'],
    ),
  ];

  // User's listed cars
  final List<Map<String, dynamic>> _myListedCars = [];

  List<RentalCar> get _filteredCars {
    return _allCars.where((car) {
      final matchesCategory =
          _selectedCategory == 'All' || car.type == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          car.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          car.type.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Car Rental',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildToggle('Rent a Car', _isRentMode),
                        _buildToggle('List Your Car', !_isRentMode),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isRentMode ? _buildRentView() : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isRentMode = label == 'Rent a Car'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isSelected ? Colors.black : Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildRentView() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey.shade400, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search cars...',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close,
                        size: 20, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ),

        // Categories
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: ['All', 'Hatchback', 'Sedan', 'SUV'].map((category) {
              final isSelected = _selectedCategory == category;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = category),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.primary : Colors.grey.shade300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      category,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isSelected ? Colors.black : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_filteredCars.length} cars available',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Car listings
        Expanded(
          child: _filteredCars.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No cars found',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredCars.length,
                  itemBuilder: (context, index) =>
                      _buildCarCard(_filteredCars[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildCarCard(RentalCar car) {
    return GestureDetector(
      onTap: () => _showCarDetails(car),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 90,
              height: 70,
              decoration: BoxDecoration(
                color: car.imageColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(Icons.directions_car, size: 36, color: car.imageColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    '${car.type} • ${car.transmission}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                      const SizedBox(width: 3),
                      Text(
                        '${car.rating} (${car.trips} trips)',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        car.distance,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${car.pricePerDay.toInt()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '/day',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCarDetails(RentalCar car) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _CarDetailsSheet(
          car: car,
          scrollController: scrollController,
          onBook: () => _showBookingFlow(car),
        ),
      ),
    );
  }

  void _showBookingFlow(RentalCar car) {
    Navigator.pop(context); // Close details sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BookingSheet(car: car),
    );
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Earnings card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Earnings',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_myListedCars.fold<int>(0, (sum, car) => sum + ((car['earnings'] ?? 0) as int))}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_myListedCars.length} car${_myListedCars.length == 1 ? '' : 's'} listed',
                  style: TextStyle(
                      fontSize: 12, color: Colors.black.withOpacity(0.7)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // My listings
          if (_myListedCars.isNotEmpty) ...[
            const Text(
              'Your Listed Cars',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ..._myListedCars.map((car) => _buildMyCarCard(car)),
            const SizedBox(height: 20),
          ],

          // Add car button
          GestureDetector(
            onTap: _showAddCarSheet,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add a New Car',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text(
                          'Start earning money',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Why list with us?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInfoPoint('Earn up to ₹30,000/month'),
                _buildInfoPoint('Insurance coverage included'),
                _buildInfoPoint('Verified renters only'),
                _buildInfoPoint('You control availability'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCarCard(Map<String, dynamic> car) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_car, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${car['brand']} ${car['model']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '₹${car['price']}/day',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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

  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(fontSize: 13, color: Colors.blue.shade800)),
        ],
      ),
    );
  }

  void _showAddCarSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddCarSheet(
        onSubmit: (carData) {
          setState(() {
            _myListedCars.add({
              ...carData,
              'earnings': 0,
              'status': 'active',
            });
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${carData['brand']} ${carData['model']} listed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}

// ==================== CAR DETAILS SHEET ====================
class _CarDetailsSheet extends StatelessWidget {
  final RentalCar car;
  final ScrollController scrollController;
  final VoidCallback onBook;

  const _CarDetailsSheet({
    required this.car,
    required this.scrollController,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Car image
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: car.imageColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.directions_car,
                      size: 80, color: car.imageColor),
                ),

                const SizedBox(height: 20),

                // Name and price
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            '${car.type} • ${car.transmission}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${car.pricePerDay.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        Text('/day',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Rating and owner
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber.shade600, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${car.rating}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(' (${car.trips} trips)',
                        style: TextStyle(color: Colors.grey.shade500)),
                    const Spacer(),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey.shade300,
                      child: const Icon(Icons.person, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(car.owner),
                  ],
                ),

                const SizedBox(height: 24),

                // Features
                const Text(
                  'Features',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: car.features
                      .map((f) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child:
                                Text(f, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 24),

                // Policies
                const Text(
                  'Rental Policies',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildPolicyItem('Fuel', 'Same-to-same fuel policy'),
                _buildPolicyItem('Km limit', '300 km/day included'),
                _buildPolicyItem('Extra km', '₹12/km beyond limit'),
                _buildPolicyItem('Late return', '₹200/hour'),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Book button
        Container(
          padding: const EdgeInsets.all(16),
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Book This Car',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(title, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ==================== BOOKING SHEET ====================
class _BookingSheet extends StatefulWidget {
  final RentalCar car;

  const _BookingSheet({required this.car});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));

  int get _days => _endDate.difference(_startDate).inDays;
  double get _total => widget.car.pricePerDay * _days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Book ${widget.car.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 20),

            // Date selection
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker('Start Date', _startDate, (date) {
                    setState(() {
                      _startDate = date;
                      if (_endDate.isBefore(_startDate)) {
                        _endDate = _startDate.add(const Duration(days: 1));
                      }
                    });
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDatePicker('End Date', _endDate, (date) {
                    if (date.isAfter(_startDate)) {
                      setState(() => _endDate = date);
                    }
                  }),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Price breakdown
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹${widget.car.pricePerDay.toInt()} × $_days days'),
                      Text('₹${_total.toInt()}'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '₹${_total.toInt()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Booking confirmed for ${widget.car.name}!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Confirm Booking • ₹${_total.toInt()}'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(
      String label, DateTime date, Function(DateTime) onSelect) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ADD CAR SHEET ====================
class _AddCarSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const _AddCarSheet({required this.onSubmit});

  @override
  State<_AddCarSheet> createState() => _AddCarSheetState();
}

class _AddCarSheetState extends State<_AddCarSheet> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _priceController = TextEditingController();
  String _transmission = 'Manual';

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Add Your Car',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 20),

              _buildTextField(
                  'Car Brand', _brandController, 'e.g. Maruti, Hyundai'),
              _buildTextField(
                  'Car Model', _modelController, 'e.g. Swift, Creta'),
              _buildTextField('Year', _yearController, 'e.g. 2022',
                  isNumber: true),
              _buildTextField('Daily Rate (₹)', _priceController, 'e.g. 1500',
                  isNumber: true),

              // Transmission
              const SizedBox(height: 8),
              const Text('Transmission',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: ['Manual', 'Automatic'].map((t) {
                  final isSelected = _transmission == t;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _transmission = t),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.black
                                : Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('List My Car',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, String hint,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit({
        'brand': _brandController.text,
        'model': _modelController.text,
        'year': _yearController.text,
        'price': int.tryParse(_priceController.text) ?? 0,
        'transmission': _transmission,
      });
    }
  }
}
