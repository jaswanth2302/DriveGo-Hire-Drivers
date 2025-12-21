/// Car Type & Transmission Models for Drivo
/// Production-ready data structures for vehicle selection

enum TransmissionType {
  manual,
  automatic,
}

extension TransmissionTypeExtension on TransmissionType {
  String get displayName {
    switch (this) {
      case TransmissionType.manual:
        return 'Manual';
      case TransmissionType.automatic:
        return 'Automatic';
    }
  }

  String get shortLabel {
    switch (this) {
      case TransmissionType.manual:
        return 'MT';
      case TransmissionType.automatic:
        return 'AT';
    }
  }
}

enum CarCategory {
  hatchback,
  sedan,
  compactSuv,
  midSuv,
  mpv,
  electric,
}

extension CarCategoryExtension on CarCategory {
  String get displayName {
    switch (this) {
      case CarCategory.hatchback:
        return 'Hatchback';
      case CarCategory.sedan:
        return 'Sedan';
      case CarCategory.compactSuv:
        return 'Compact SUV';
      case CarCategory.midSuv:
        return 'Mid SUV';
      case CarCategory.mpv:
        return 'MPV';
      case CarCategory.electric:
        return 'Electric';
    }
  }

  String get icon {
    switch (this) {
      case CarCategory.hatchback:
        return '🚗';
      case CarCategory.sedan:
        return '🚙';
      case CarCategory.compactSuv:
        return '🚜';
      case CarCategory.midSuv:
        return '🚐';
      case CarCategory.mpv:
        return '🚌';
      case CarCategory.electric:
        return '⚡';
    }
  }
}

/// Represents a selectable car type option
class CarType {
  final String id;
  final CarCategory category;
  final TransmissionType transmission;
  final String displayName;
  final List<String> exampleModels;
  final double pricePerHour;
  final bool isAvailable;
  final String? unavailableReason;

  const CarType({
    required this.id,
    required this.category,
    required this.transmission,
    required this.displayName,
    required this.exampleModels,
    required this.pricePerHour,
    this.isAvailable = true,
    this.unavailableReason,
  });

  /// Factory to create from JSON (backend response)
  factory CarType.fromJson(Map<String, dynamic> json) {
    return CarType(
      id: json['id'] as String,
      category: CarCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => CarCategory.hatchback,
      ),
      transmission: json['transmission'] == 'automatic'
          ? TransmissionType.automatic
          : TransmissionType.manual,
      displayName: json['display_name'] as String,
      exampleModels: List<String>.from(json['example_models'] ?? []),
      pricePerHour: (json['price_per_hour'] as num).toDouble(),
      isAvailable: json['is_available'] as bool? ?? true,
      unavailableReason: json['unavailable_reason'] as String?,
    );
  }

  /// Convert to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'car_type': id,
      'category': category.name,
      'transmission': transmission.name,
      'base_price_per_hour': pricePerHour,
    };
  }
}

/// Service to fetch car types and pricing
class CarTypeService {
  /// Get available car types for a transmission
  /// In real app, this fetches from backend
  Future<List<CarType>> getCarTypes(TransmissionType transmission) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    if (transmission == TransmissionType.manual) {
      return _manualCarTypes;
    } else {
      return _automaticCarTypes;
    }
  }

  /// Get all car types
  Future<Map<TransmissionType, List<CarType>>> getAllCarTypes() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      TransmissionType.manual: _manualCarTypes,
      TransmissionType.automatic: _automaticCarTypes,
    };
  }

  // =============== MOCK DATA ===============
  // In production, this comes from backend config

  static const List<CarType> _manualCarTypes = [
    CarType(
      id: 'hatchback_manual',
      category: CarCategory.hatchback,
      transmission: TransmissionType.manual,
      displayName: 'Hatchback',
      exampleModels: ['Alto', 'Swift', 'i10', 'Tiago'],
      pricePerHour: 199,
    ),
    CarType(
      id: 'sedan_manual',
      category: CarCategory.sedan,
      transmission: TransmissionType.manual,
      displayName: 'Sedan',
      exampleModels: ['Dzire', 'Amaze', 'City', 'Verna'],
      pricePerHour: 209,
    ),
    CarType(
      id: 'compact_suv_manual',
      category: CarCategory.compactSuv,
      transmission: TransmissionType.manual,
      displayName: 'Compact SUV',
      exampleModels: ['Nexon', 'Brezza', 'Venue', 'Sonet'],
      pricePerHour: 219,
    ),
    CarType(
      id: 'mid_suv_manual',
      category: CarCategory.midSuv,
      transmission: TransmissionType.manual,
      displayName: 'Mid SUV',
      exampleModels: ['Creta', 'Seltos', 'XUV500'],
      pricePerHour: 229,
    ),
    CarType(
      id: 'mpv_manual',
      category: CarCategory.mpv,
      transmission: TransmissionType.manual,
      displayName: 'MPV',
      exampleModels: ['Ertiga', 'Innova', 'Marazzo'],
      pricePerHour: 239,
    ),
  ];

  static const List<CarType> _automaticCarTypes = [
    CarType(
      id: 'hatchback_auto',
      category: CarCategory.hatchback,
      transmission: TransmissionType.automatic,
      displayName: 'Hatchback (Auto)',
      exampleModels: ['i10 AT', 'Swift AT', 'Baleno AT'],
      pricePerHour: 219,
    ),
    CarType(
      id: 'sedan_auto',
      category: CarCategory.sedan,
      transmission: TransmissionType.automatic,
      displayName: 'Sedan (Auto)',
      exampleModels: ['City AT', 'Verna AT', 'Ciaz AT'],
      pricePerHour: 229,
    ),
    CarType(
      id: 'compact_suv_auto',
      category: CarCategory.compactSuv,
      transmission: TransmissionType.automatic,
      displayName: 'Compact SUV (Auto)',
      exampleModels: ['Nexon AT', 'Venue AT', 'Sonet AT'],
      pricePerHour: 239,
    ),
    CarType(
      id: 'mid_suv_auto',
      category: CarCategory.midSuv,
      transmission: TransmissionType.automatic,
      displayName: 'Mid SUV (Auto)',
      exampleModels: ['Creta AT', 'Seltos AT'],
      pricePerHour: 249,
    ),
    CarType(
      id: 'electric',
      category: CarCategory.electric,
      transmission: TransmissionType.automatic,
      displayName: 'Electric',
      exampleModels: ['Nexon EV', 'MG ZS EV', 'Tata Tigor EV'],
      pricePerHour: 259,
    ),
  ];
}
