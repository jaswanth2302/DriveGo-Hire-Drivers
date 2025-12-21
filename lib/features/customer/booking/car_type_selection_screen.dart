import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../data/models/car_type_models.dart';

/// Rapido-style Car Type & Transmission Selection Screen
/// Fast, clear, and price-transparent
class CarTypeSelectionScreen extends ConsumerStatefulWidget {
  final String pickupAddress;
  final VoidCallback? onContinue;
  final ValueChanged<CarType>? onCarTypeSelected;

  const CarTypeSelectionScreen({
    super.key,
    required this.pickupAddress,
    this.onContinue,
    this.onCarTypeSelected,
  });

  @override
  ConsumerState<CarTypeSelectionScreen> createState() =>
      _CarTypeSelectionScreenState();
}

class _CarTypeSelectionScreenState extends ConsumerState<CarTypeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CarTypeService _carTypeService = CarTypeService();

  TransmissionType _selectedTransmission = TransmissionType.manual;
  CarType? _selectedCarType;
  List<CarType> _carTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCarTypes();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _selectedTransmission = _tabController.index == 0
          ? TransmissionType.manual
          : TransmissionType.automatic;
      _selectedCarType = null; // Reset selection on tab change
    });
    _loadCarTypes();
  }

  Future<void> _loadCarTypes() async {
    setState(() => _isLoading = true);
    final types = await _carTypeService.getCarTypes(_selectedTransmission);
    if (mounted) {
      setState(() {
        _carTypes = types;
        _isLoading = false;
      });
    }
  }

  void _selectCarType(CarType carType) {
    if (!carType.isAvailable) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedCarType = carType;
    });
    widget.onCarTypeSelected?.call(carType);
  }

  void _confirmSelection() {
    if (_selectedCarType == null) return;
    HapticFeedback.mediumImpact();
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Fixed Header
          _buildHeader(context),

          // Transmission Toggle
          _buildTransmissionToggle(context),

          // Car Type List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCarTypeList(context),
          ),

          // Bottom CTA
          _buildBottomCTA(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back and title
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Select your car type',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pickup location indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.pickupAddress,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

  Widget _buildTransmissionToggle(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorPadding: const EdgeInsets.all(4),
          labelColor: Colors.black,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.settings,
                    size: 18,
                    color: _selectedTransmission == TransmissionType.manual
                        ? Colors.black
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  const Text('Manual'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: _selectedTransmission == TransmissionType.automatic
                        ? Colors.black
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  const Text('Automatic'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarTypeList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _carTypes.length + 1, // +1 for the info card
      itemBuilder: (context, index) {
        if (index == 0 && _selectedTransmission == TransmissionType.automatic) {
          // Info card for automatic
          return _buildAutomaticInfoCard(context);
        }

        final adjustedIndex =
            _selectedTransmission == TransmissionType.automatic
                ? index - 1
                : index;

        if (adjustedIndex >= _carTypes.length || adjustedIndex < 0) {
          return const SizedBox.shrink();
        }

        final carType = _carTypes[adjustedIndex];
        final isSelected = _selectedCarType?.id == carType.id;

        return _buildCarTypeCard(context, carType, isSelected);
      },
    );
  }

  Widget _buildAutomaticInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Requires automatic-trained driver',
              style: TextStyle(
                color: AppColors.info,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarTypeCard(
      BuildContext context, CarType carType, bool isSelected) {
    return ScaleButton(
      onPressed: () => _selectCarType(carType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : carType.isAvailable
                    ? AppColors.border
                    : AppColors.border.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Opacity(
          opacity: carType.isAvailable ? 1.0 : 0.5,
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 16),

              // Car icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getCategoryColor(carType.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    carType.category.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Car details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          carType.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (carType.category == CarCategory.electric) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ECO',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      carType.exampleModels.join(', '),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Experienced driver assigned',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (!carType.isAvailable &&
                        carType.unavailableReason != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        carType.unavailableReason!,
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${carType.pricePerHour.toInt()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '/hr',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(CarCategory category) {
    switch (category) {
      case CarCategory.hatchback:
        return AppColors.primary;
      case CarCategory.sedan:
        return AppColors.info;
      case CarCategory.compactSuv:
        return AppColors.warning;
      case CarCategory.midSuv:
        return AppColors.secondary;
      case CarCategory.mpv:
        return Colors.purple;
      case CarCategory.electric:
        return AppColors.success;
    }
  }

  Widget _buildBottomCTA(BuildContext context) {
    final hasSelection = _selectedCarType != null;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Price summary
          if (hasSelection) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCarType!.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_selectedCarType!.transmission.displayName} • ${_selectedCarType!.exampleModels.first}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${_selectedCarType!.pricePerHour.toInt()}/hr',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasSelection ? _confirmSelection : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelection
                    ? AppColors.primary
                    : AppColors.textSecondary.withOpacity(0.3),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: hasSelection ? 2 : 0,
              ),
              child: Text(
                hasSelection ? 'Confirm & Continue' : 'Select a car type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: hasSelection ? Colors.black : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
