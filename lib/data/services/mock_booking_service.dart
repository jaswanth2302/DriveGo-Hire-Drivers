import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/booking_models.dart';

class MockBookingService {
  Future<Driver> findDriver() async {
    // Simulate searching delay
    await Future.delayed(const Duration(seconds: 3));

    return Driver(
      id: const Uuid().v4(),
      name: 'Ramesh Kumar',
      photoUrl: 'https://i.pravatar.cc/150?u=ramesh',
      rating: 4.8,
      carModel: 'Maruti Swift',
      plateNumber: 'KA-05-MJ-2023',
    );
  }

  Future<Booking> createBooking(
      String userId, String serviceType, double price) async {
    await Future.delayed(const Duration(seconds: 1));
    return Booking(
      id: const Uuid().v4(),
      customerId: userId,
      status: BookingStatus.searching,
      price: price,
      serviceType: serviceType,
    );
  }
}

final bookingServiceProvider = Provider<MockBookingService>((ref) {
  return MockBookingService();
});
