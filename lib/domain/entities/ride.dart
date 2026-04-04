// lib/domain/entities/ride.dart
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RideStatus { scheduled, active, completed, cancelled }

class Ride extends Equatable {
  final String id;
  final String driverId;
  final String driverName;
  final double driverRating;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehiclePlate;
  final String originAddress;
  final String destinationAddress;
  final LatLng origin;
  final LatLng destination;
  final String routePolyline;
  final int availableSeats;
  final double pricePerSeat;
  final DateTime departureTime;
  final RideStatus status;
  final double? distanceToPickupM;

  const Ride({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.driverRating = 5.0,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.vehiclePlate,
    required this.originAddress,
    required this.destinationAddress,
    required this.origin,
    required this.destination,
    required this.routePolyline,
    required this.availableSeats,
    this.pricePerSeat = 0,
    required this.departureTime,
    this.status = RideStatus.scheduled,
    this.distanceToPickupM,
  });

  String get vehicleInfo =>
      '${vehicleColor ?? ''} ${vehicleMake ?? ''} ${vehicleModel ?? ''}'.trim();

  bool get isFree => pricePerSeat == 0;

  String get priceDisplay =>
      isFree ? 'Free' : '₹${pricePerSeat.toStringAsFixed(0)}';

  @override
  List<Object?> get props => [id, driverId, status];

  Ride copyWith({
    String? id,
    String? driverId,
    String? driverName,
    double? driverRating,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    String? vehiclePlate,
    String? originAddress,
    String? destinationAddress,
    LatLng? origin,
    LatLng? destination,
    String? routePolyline,
    int? availableSeats,
    double? pricePerSeat,
    DateTime? departureTime,
    RideStatus? status,
    double? distanceToPickupM,
  }) {
    return Ride(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverRating: driverRating ?? this.driverRating,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      routePolyline: routePolyline ?? this.routePolyline,
      availableSeats: availableSeats ?? this.availableSeats,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      departureTime: departureTime ?? this.departureTime,
      status: status ?? this.status,
      distanceToPickupM: distanceToPickupM ?? this.distanceToPickupM,
    );
  }
}

// lib/domain/entities/booking.dart
enum BookingStatus {
  pending,
  accepted,
  rejected,
  inProgress,
  completed,
  cancelled
}

class Booking extends Equatable {
  final String id;
  final String rideId;
  final String passengerId;
  final String? passengerName;
  final double? passengerRating;
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String otpCode;
  final bool otpVerified;
  final int seatsRequested;
  final double fareAmount;
  final BookingStatus status;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.rideId,
    required this.passengerId,
    this.passengerName,
    this.passengerRating,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.otpCode,
    this.otpVerified = false,
    this.seatsRequested = 1,
    this.fareAmount = 0,
    this.status = BookingStatus.pending,
    required this.createdAt,
  });

  bool get isPending => status == BookingStatus.pending;
  bool get isAccepted => status == BookingStatus.accepted;
  bool get isActive => status == BookingStatus.inProgress;

  @override
  List<Object?> get props => [id, rideId, passengerId, status];

  Booking copyWith({
    String? id,
    String? rideId,
    String? passengerId,
    String? passengerName,
    double? passengerRating,
    String? pickupAddress,
    String? dropoffAddress,
    LatLng? pickupLocation,
    LatLng? dropoffLocation,
    String? otpCode,
    bool? otpVerified,
    int? seatsRequested,
    double? fareAmount,
    BookingStatus? status,
    DateTime? createdAt,
  }) {
    return Booking(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerRating: passengerRating ?? this.passengerRating,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      otpCode: otpCode ?? this.otpCode,
      otpVerified: otpVerified ?? this.otpVerified,
      seatsRequested: seatsRequested ?? this.seatsRequested,
      fareAmount: fareAmount ?? this.fareAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
