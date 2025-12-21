import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/pricing_models.dart';

/// Long Trip Booking Screen - Outstation & Multi-day Trips
/// Mandatory round trip with driver accommodation
class LongTripScreen extends StatefulWidget {
  const LongTripScreen({super.key});

  @override
  State<LongTripScreen> createState() => _LongTripScreenState();
}

class _LongTripScreenState extends State<LongTripScreen> {
  int _currentStep = 0;

  // Trip details
  String _fromCity = '';
  String _toCity = '';
  int _tripDays = 2;
  int _estimatedKm = 0;

  // Vehicle details
  String _carType = 'Sedan';
  String _transmission = 'Automatic';

  // Pricing constants
  static const double drivingPerDay = 1800.0; // 8 hrs avg
  static const double accommodationPerNight = 500.0;
  static const double foodPerDay = 300.0;
  static const double nightHaltPerNight = 200.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Long Trip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Round Trip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  _buildProgressDot(0),
                  _buildProgressLine(0),
                  _buildProgressDot(1),
                  _buildProgressLine(1),
                  _buildProgressDot(2),
                ],
              ),
            ),

            Expanded(
              child: _currentStep == 0
                  ? _buildTripDetailsStep()
                  : _currentStep == 1
                      ? _buildVehicleStep()
                      : _buildCostBreakdownStep(),
            ),

            // Bottom button
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
                    onPressed: _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _currentStep == 2 ? 'Confirm Booking' : 'Continue',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDot(int step) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.grey.shade200,
        shape: BoxShape.circle,
        border: isCurrent ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: Center(
        child: Text(
          '${step + 1}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isActive ? Colors.black : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressLine(int afterStep) {
    final isActive = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isActive ? AppColors.primary : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildTripDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),

          // From city
          _buildCityInput(
            label: 'From',
            value: _fromCity,
            onTap: () => _selectCity(true),
            icon: Icons.circle,
            iconColor: Colors.green,
          ),

          const SizedBox(height: 12),

          // To city
          _buildCityInput(
            label: 'To',
            value: _toCity,
            onTap: () => _selectCity(false),
            icon: Icons.location_on,
            iconColor: Colors.red,
          ),

          const SizedBox(height: 20),

          // Trip days
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Trip Duration',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_tripDays - 1} night${_tripDays > 2 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDayButton(false),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_tripDays days',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    _buildDayButton(true),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Estimated km
          if (_estimatedKm > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.route, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  Text(
                    'Estimated: $_estimatedKm km (round trip)',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Info note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Long trips are always round trip. Driver accommodation & food included.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityInput({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value.isEmpty ? 'Select city' : value,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color:
                          value.isEmpty ? Colors.grey.shade400 : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildDayButton(bool isAdd) {
    final canChange = isAdd ? _tripDays < 14 : _tripDays > 2;
    return GestureDetector(
      onTap:
          canChange ? () => setState(() => _tripDays += isAdd ? 1 : -1) : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: canChange ? Colors.grey.shade100 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            isAdd ? '+' : '−',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: canChange ? Colors.black : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),

          // Car type
          const Text(
            'Car Type',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildCarTypeOption('Hatchback'),
              const SizedBox(width: 10),
              _buildCarTypeOption('Sedan'),
              const SizedBox(width: 10),
              _buildCarTypeOption('SUV'),
            ],
          ),

          const SizedBox(height: 24),

          // Transmission
          const Text(
            'Transmission',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTransmissionOption('Manual'),
              const SizedBox(width: 10),
              _buildTransmissionOption('Automatic'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarTypeOption(String type) {
    final isSelected = _carType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _carType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Text(
                type,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? Colors.black : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransmissionOption(String type) {
    final isSelected = _transmission == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _transmission = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade200,
            ),
          ),
          child: Text(
            type,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isSelected ? Colors.black : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildCostBreakdownStep() {
    final nights = _tripDays - 1;
    final drivingTotal = drivingPerDay * _tripDays;
    final accommodationTotal = accommodationPerNight * nights;
    final foodTotal = foodPerDay * _tripDays;
    final nightHaltTotal = nightHaltPerNight * nights;
    final grandTotal =
        drivingTotal + accommodationTotal + foodTotal + nightHaltTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cost Breakdown',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_fromCity → $_toCity',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildCostRow('Driver (${_tripDays} days)', drivingTotal),
                _buildCostDivider(),
                _buildCostRow(
                    'Accommodation ($nights nights)', accommodationTotal),
                _buildCostDivider(),
                _buildCostRow('Food Allowance (${_tripDays} days)', foodTotal),
                _buildCostDivider(),
                _buildCostRow('Night Halt ($nights nights)', nightHaltTotal),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(11),
                      bottomRight: Radius.circular(11),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '₹${grandTotal.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Inclusions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What\'s Included',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                _buildInclusionItem('Professional driver'),
                _buildInclusionItem('Driver accommodation'),
                _buildInclusionItem('Driver food allowance'),
                _buildInclusionItem('Round trip return'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Cost per day
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cost per day',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '₹${(grandTotal / _tripDays).toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            '₹${amount.toInt()}',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCostDivider() {
    return Divider(height: 1, color: Colors.grey.shade200);
  }

  Widget _buildInclusionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.green.shade800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _selectCity(bool isFrom) async {
    // Mock city selection - in production, use proper search
    final cities = [
      'Bangalore',
      'Chennai',
      'Hyderabad',
      'Mumbai',
      'Pune',
      'Goa',
      'Coorg',
      'Ooty'
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFrom ? 'Select pickup city' : 'Select destination',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...cities.map((city) => ListTile(
                  title: Text(city),
                  onTap: () => Navigator.pop(context, city),
                )),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        if (isFrom) {
          _fromCity = selected;
        } else {
          _toCity = selected;
        }
        // Mock km calculation
        if (_fromCity.isNotEmpty && _toCity.isNotEmpty) {
          _estimatedKm = 300 + (_fromCity.length + _toCity.length) * 20;
        }
      });
    }
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (_fromCity.isEmpty || _toCity.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both cities')),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      // Confirm booking
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Long trip booking coming soon!')),
      );
    }
  }
}
