import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../datasources/supabase_datasource.dart';
import '../datasources/maps_service.dart';
import '../models/profile_model.dart';

abstract class RideRepository {
  Future<List<RideModel>> findMatchingRides({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String vehicleType = 'car',
    int seatsNeeded = 1,
  });

  Future<RideModel> createRide({
    required String driverId,
    required String originAddress,
    required String destinationAddress,
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    required String routePolyline,
    required int availableSeats,
    required DateTime departureTime,
    double? pricePerSeat,
    String vehicleType = 'car',
  });

  Future<BookingModel> requestSeat({
    required String rideId,
    required String passengerId,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    int seatsRequested = 1,
    String vehicleType = 'car',
  });

  Future<bool> acceptBooking(String bookingId);
  Future<bool> rejectBooking(String bookingId);
  Future<bool> verifyOtp({required String bookingId, required String otp});
  Future<bool> startRide(String rideId);
  Future<bool> completeRide(String rideId);
  Future<List<BookingModel>> getRideBookings(String rideId);
  Future<ProfileModel?> getProfile(String userId);
  Future<ProfileModel> upsertProfile(ProfileModel profile);
}

class RideRepositoryImpl implements RideRepository {
  final SupabaseDataSource _supabase;
  final MapsService _mapsService;

  RideRepositoryImpl({
    required SupabaseDataSource supabase,
    required MapsService mapsService,
  })  : _supabase = supabase,
        _mapsService = mapsService;

  // ─── Find Matching Rides (400m corridor) ─────────────────────────────────
  @override
  Future<List<RideModel>> findMatchingRides({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String vehicleType = 'car',
    int seatsNeeded = 1,
  }) async {
    // 1. Try Supabase RPC (PostGIS spatial query)
    final serverResults = await _supabase.findMatchingRides(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      vehicleType: vehicleType,
      seatsNeeded: seatsNeeded,
    );

    if (serverResults.isNotEmpty) return serverResults;

    // 2. Client-side fallback: fetch active rides and filter
    final pickup = LatLng(pickupLat, pickupLng);
    final dropoff = LatLng(dropoffLat, dropoffLng);

    // Get all pending rides (limited fetch)
    try {
      final allRides = await _supabase.client
          .from('rides')
          .select('*, driver:profiles(*)')
          .eq('status', 'pending')
          .limit(50);

      final rides = (allRides as List)
          .map((e) => RideModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Client-side 400m corridor filter
      return rides.where((ride) {
        if (ride.routePolyline.isEmpty) return false;
        final polyPoints = _mapsService.decodePolyline(ride.routePolyline);
        if (polyPoints.isEmpty) return false;

        final pickupNear = _mapsService.isPointNearPolyline(
          point: pickup,
          polylinePoints: polyPoints,
        );
        final dropoffNear = _mapsService.isPointNearPolyline(
          point: dropoff,
          polylinePoints: polyPoints,
        );

        return pickupNear && dropoffNear;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Create Ride ──────────────────────────────────────────────────────────
  @override
  Future<RideModel> createRide({
    required String driverId,
    required String originAddress,
    required String destinationAddress,
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    required String routePolyline,
    required int availableSeats,
    required DateTime departureTime,
    double? pricePerSeat,
    String vehicleType = 'car',
  }) async {
    return await _supabase.createRide(
      driverId: driverId,
      originAddress: originAddress,
      destinationAddress: destinationAddress,
      originLat: originLat,
      originLng: originLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      routePolyline: routePolyline,
      availableSeats: availableSeats,
      departureTime: departureTime,
      pricePerSeat: pricePerSeat,
      vehicleType: vehicleType,
    );
  }

  // ─── Request Seat ─────────────────────────────────────────────────────────
  @override
  Future<BookingModel> requestSeat({
    required String rideId,
    required String passengerId,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    int seatsRequested = 1,
    String vehicleType = 'car',
  }) async {
    return await _supabase.createBooking(
      rideId: rideId,
      passengerId: passengerId,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      seatsRequested: seatsRequested,
      vehicleType: vehicleType,
    );
  }

  // ─── Booking Actions ──────────────────────────────────────────────────────
  @override
  Future<bool> acceptBooking(String bookingId) async {
    try {
      await _supabase.updateBookingStatus(
        bookingId: bookingId,
        status: 'accepted',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> rejectBooking(String bookingId) async {
    try {
      await _supabase.updateBookingStatus(
        bookingId: bookingId,
        status: 'rejected',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> verifyOtp({
    required String bookingId,
    required String otp,
  }) async {
    return await _supabase.verifyOtp(bookingId: bookingId, otp: otp);
  }

  @override
  Future<bool> startRide(String rideId) async {
    try {
      await _supabase.updateRideStatus(
          rideId: rideId, status: 'in_progress');
      // Also update all accepted bookings
      final bookings = await _supabase.getBookingsByRide(rideId);
      for (final b in bookings) {
        if (b.isAccepted) {
          await _supabase.updateBookingStatus(
              bookingId: b.id, status: 'in_progress');
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> completeRide(String rideId) async {
    try {
      await _supabase.updateRideStatus(rideId: rideId, status: 'completed');
      final bookings = await _supabase.getBookingsByRide(rideId);
      for (final b in bookings) {
        if (b.isInProgress) {
          await _supabase.updateBookingStatus(
              bookingId: b.id, status: 'completed');
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BookingModel>> getRideBookings(String rideId) async {
    return await _supabase.getBookingsByRide(rideId);
  }

  // ─── Profile ──────────────────────────────────────────────────────────────
  @override
  Future<ProfileModel?> getProfile(String userId) async {
    return await _supabase.getProfile(userId);
  }

  @override
  Future<ProfileModel> upsertProfile(ProfileModel profile) async {
    return await _supabase.upsertProfile(profile);
  }
}