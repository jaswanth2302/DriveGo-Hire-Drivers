import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../data/services/geocoding_service.dart';
import '../../../data/services/location_service.dart';

class LocationSearchScreen extends ConsumerStatefulWidget {
  final String title;
  final LatLng? initialLocation;

  const LocationSearchScreen({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  ConsumerState<LocationSearchScreen> createState() =>
      _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<LocationSearchScreen> {
  final _searchController = TextEditingController();
  List<Place> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    final service = ref.read(geocodingServiceProvider);
    final results = await service.searchPlaces(query);

    setState(() {
      _suggestions = results;
      _isLoading = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);

    final locationService = ref.read(locationServiceProvider);
    final geocodingService = ref.read(geocodingServiceProvider);

    try {
      final location = await locationService.getCurrentLocation();
      final address = await geocodingService.reverseGeocode(location);

      if (mounted) {
        context.pop({
          'location': location,
          'address': address ?? 'Current Location',
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectPlace(Place place) {
    context.pop({
      'location': place.location,
      'address': place.shortName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FadeSlideTransition(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search for a location...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _suggestions = []);
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Use Current Location
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.my_location, color: AppColors.secondary),
              ),
              title: const Text('Use Current Location'),
              subtitle: const Text('Get your GPS location'),
              onTap: _useCurrentLocation,
            ),

            const Divider(),

            // Loading or Results
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (_suggestions.isEmpty && _searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      'No locations found',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final place = _suggestions[index];
                    return StaggeredListItem(
                      index: index,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.location_on,
                              color: AppColors.textSecondary),
                        ),
                        title: Text(
                          place.shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          place.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => _selectPlace(place),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
