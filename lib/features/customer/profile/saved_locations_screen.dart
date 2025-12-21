import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_widgets.dart';

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  final List<Map<String, dynamic>> _locations = [
    {
      'type': 'home',
      'icon': Icons.home_rounded,
      'label': 'Home',
      'address': 'Add your home address',
      'isSet': false,
    },
    {
      'type': 'work',
      'icon': Icons.work_rounded,
      'label': 'Work',
      'address': 'Add your work address',
      'isSet': false,
    },
  ];

  final List<Map<String, dynamic>> _favorites = [
    {
      'label': 'Gym',
      'address': 'Cult Fitness, Indiranagar',
      'icon': Icons.fitness_center,
    },
    {
      'label': "Parent's Home",
      'address': 'Jayanagar 4th Block',
      'icon': Icons.favorite,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewLocation,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Location'),
      ),
      body: FadeSlideTransition(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary Locations (Home, Work)
              ..._locations.map((loc) => _buildLocationCard(
                    context,
                    icon: loc['icon'],
                    label: loc['label'],
                    address: loc['address'],
                    isSet: loc['isSet'],
                    isPrimary: true,
                  )),

              const SizedBox(height: 24),

              // Favorites Section
              Text(
                'Favorites',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ..._favorites.asMap().entries.map((entry) {
                final loc = entry.value;
                return StaggeredListItem(
                  index: entry.key,
                  child: _buildLocationCard(
                    context,
                    icon: loc['icon'],
                    label: loc['label'],
                    address: loc['address'],
                    isSet: true,
                    isPrimary: false,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String address,
    required bool isSet,
    required bool isPrimary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary && !isSet
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.border,
          style: isPrimary && !isSet ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPrimary
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isPrimary ? AppColors.secondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSet
                            ? AppColors.textSecondary
                            : AppColors.textHint,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isSet)
            Icon(Icons.add, color: AppColors.primary)
          else
            Icon(Icons.edit_outlined, color: AppColors.textHint),
        ],
      ),
    );
  }

  void _addNewLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add location feature coming soon!')),
    );
  }
}
