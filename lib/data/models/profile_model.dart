import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/live_location.dart';

class ProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final String? vehicleNumber;
  final String? vehicleModel;
  final String? vehicleColor;
  final bool isDriver;
  final double rating;
  final int totalRides;
  final bool isAadhaarVerified;
  final String? aadhaarLastFour;
  final String? gender;
  final DateTime? dob;
  final DateTime createdAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
    this.vehicleNumber,
    this.vehicleModel,
    this.vehicleColor,
    this.isDriver = false,
    this.rating = 5.0,
    this.totalRides = 0,
    this.isAadhaarVerified = false,
    this.aadhaarLastFour,
    this.gender,
    this.dob,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      isDriver: json['is_driver'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalRides: json['total_rides'] as int? ?? 0,
      isAadhaarVerified: json['is_aadhaar_verified'] as bool? ?? false,
      aadhaarLastFour: json['aadhaar_last_four'] as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'vehicle_number': vehicleNumber,
      'vehicle_model': vehicleModel,
      'vehicle_color': vehicleColor,
      'is_driver': isDriver,
      'rating': rating,
      'total_rides': totalRides,
      'is_aadhaar_verified': isAadhaarVerified,
      'aadhaar_last_four': aadhaarLastFour,
      'gender': gender,
      'dob': dob?.toIso8601String().split('T').first,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? vehicleNumber,
    String? vehicleModel,
    String? vehicleColor,
    bool? isDriver,
    double? rating,
    int? totalRides,
    bool? isAadhaarVerified,
    String? aadhaarLastFour,
    String? gender,
    DateTime? dob,
  }) {
    return ProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      isDriver: isDriver ?? this.isDriver,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
      isAadhaarVerified: isAadhaarVerified ?? this.isAadhaarVerified,
      aadhaarLastFour: aadhaarLastFour ?? this.aadhaarLastFour,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      createdAt: createdAt,
    );
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  }

  bool get hasVehicle =>
      vehicleNumber != null &&
      vehicleNumber!.isNotEmpty &&
      vehicleModel != null &&
      vehicleModel!.isNotEmpty;

  @override
  String toString() =>
      'ProfileModel(id: $id, fullName: $fullName, isDriver: $isDriver)';
}


// ─── Ride Model ──────────────────────────────────────────────────────────────
class RideModel {
  final String id;
  final String driverId;
  final String originAddress;
  final String destinationAddress;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final String routePolyline;
  final int availableSeats;
  final int totalSeats;
  final DateTime departureTime;
  final String status;
  final double? pricePerSeat;
  final String? notes;
  final String vehicleType; // 'car' or 'bike'
  final ProfileModel? driver;
  final DateTime createdAt;

  const RideModel({
    required this.id,
    required this.driverId,
    required this.originAddress,
    required this.destinationAddress,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.routePolyline,
    required this.availableSeats,
    required this.totalSeats,
    required this.departureTime,
    required this.status,
    this.pricePerSeat,
    this.notes,
    this.vehicleType = 'car',
    this.driver,
    required this.createdAt,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      originAddress: json['origin_address'] as String? ?? '',
      destinationAddress: json['destination_address'] as String? ?? '',
      originLat: (json['origin_lat'] as num?)?.toDouble() ?? 0,
      originLng: (json['origin_lng'] as num?)?.toDouble() ?? 0,
      destinationLat: (json['destination_lat'] as num?)?.toDouble() ?? 0,
      destinationLng: (json['destination_lng'] as num?)?.toDouble() ?? 0,
      routePolyline: json['route_polyline'] as String? ?? '',
      availableSeats: json['available_seats'] as int? ?? 0,
      totalSeats: json['total_seats'] as int? ?? 1,
      departureTime: DateTime.parse(
        json['departure_time'] as String? ?? DateTime.now().toIso8601String(),
      ),
      status: json['status'] as String? ?? 'pending',
      pricePerSeat: (json['price_per_seat'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'car',
      driver: json['driver'] != null
          ? ProfileModel.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  RideModel copyWith({
    String? id,
    String? driverId,
    String? originAddress,
    String? destinationAddress,
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
    String? routePolyline,
    int? availableSeats,
    int? totalSeats,
    DateTime? departureTime,
    String? status,
    double? pricePerSeat,
    String? notes,
    String? vehicleType,
    ProfileModel? driver,
    DateTime? createdAt,
  }) {
    return RideModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      routePolyline: routePolyline ?? this.routePolyline,
      availableSeats: availableSeats ?? this.availableSeats,
      totalSeats: totalSeats ?? this.totalSeats,
      departureTime: departureTime ?? this.departureTime,
      status: status ?? this.status,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      notes: notes ?? this.notes,
      vehicleType: vehicleType ?? this.vehicleType,
      driver: driver ?? this.driver,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'driver_id': driverId,
        'origin_address': originAddress,
        'destination_address': destinationAddress,
        'origin_lat': originLat,
        'origin_lng': originLng,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'route_polyline': routePolyline,
        'available_seats': availableSeats,
        'total_seats': totalSeats,
        'departure_time': departureTime.toIso8601String(),
        'status': status,
        'price_per_seat': pricePerSeat,
        'notes': notes,
        'vehicle_type': vehicleType,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isActive => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get hasSeats => availableSeats > 0;

  String get departureTimeFormatted {
    final h = departureTime.hour.toString().padLeft(2, '0');
    final m = departureTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Convert to domain entity
  Ride toDomain() => toEntity();

  Ride toEntity() {
    return Ride(
      id: id,
      driverId: driverId,
      driverName: driver?.fullName ?? 'Unknown Driver',
      driverRating: driver?.rating ?? 4.5,
      vehicleMake: driver?.vehicleModel?.split(' ').first,
      vehicleModel: driver?.vehicleModel,
      vehicleColor: driver?.vehicleColor,
      vehiclePlate: driver?.vehicleNumber,
      originAddress: originAddress,
      destinationAddress: destinationAddress,
      origin: LatLng(originLat, originLng),
      destination: LatLng(destinationLat, destinationLng),
      routePolyline: routePolyline,
      availableSeats: availableSeats,
      pricePerSeat: pricePerSeat ?? 0,
      departureTime: departureTime,
      status: _mapStatus(status),
    );
  }

  RideStatus _mapStatus(String s) {
    switch (s.toLowerCase()) {
      case 'active':
      case 'in_progress':
        return RideStatus.active;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      default:
        return RideStatus.scheduled;
    }
  }
}


// ─── Booking Model ───────────────────────────────────────────────────────────
class BookingModel {
  final String id;
  final String rideId;
  final String passengerId;
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String status;
  final String? otp;
  final bool otpVerified;
  final int seatsRequested;
  final String vehicleType; // 'car' or 'bike'
  final DateTime? requestedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final ProfileModel? passenger;
  final RideModel? ride;

  const BookingModel({
    required this.id,
    required this.rideId,
    required this.passengerId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.status,
    this.otp,
    this.otpVerified = false,
    this.seatsRequested = 1,
    this.vehicleType = 'car',
    this.requestedAt,
    this.acceptedAt,
    this.completedAt,
    this.passenger,
    this.ride,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      rideId: json['ride_id'] as String,
      passengerId: json['passenger_id'] as String,
      pickupAddress: json['pickup_address'] as String? ?? '',
      dropoffAddress: json['dropoff_address'] as String? ?? '',
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? 0,
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (json['dropoff_lng'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      otp: json['otp'] as String?,
      otpVerified: json['otp_verified'] as bool? ?? false,
      seatsRequested: json['seats_requested'] as int? ?? 1,
      vehicleType: json['vehicle_type'] as String? ?? 'car',
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'] as String)
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      passenger: json['passenger'] != null
          ? ProfileModel.fromJson(json['passenger'] as Map<String, dynamic>)
          : null,
      ride: json['ride'] != null
          ? RideModel.fromJson(json['ride'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ride_id': rideId,
        'passenger_id': passengerId,
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'status': status,
        'otp': otp,
        'otp_verified': otpVerified,
        'seats_requested': seatsRequested,
        'vehicle_type': vehicleType,
        'requested_at': requestedAt?.toIso8601String(),
        'accepted_at': acceptedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isActive => status == 'in_progress';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get canCancel => isPending || isAccepted; // only cancel before OTP

  Booking toDomain() => toEntity();

  Booking toEntity() {
    return Booking(
      id: id,
      rideId: rideId,
      passengerId: passengerId,
      passengerName: passenger?.fullName,
      passengerRating: passenger?.rating,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupLocation: LatLng(pickupLat, pickupLng),
      dropoffLocation: LatLng(dropoffLat, dropoffLng),
      otpCode: otp ?? '',
      otpVerified: otpVerified,
      status: _mapStatus(status),
      createdAt: requestedAt ?? DateTime.now(),
    );
  }

  BookingStatus _mapStatus(String s) {
    switch (s.toLowerCase()) {
      case 'accepted':
        return BookingStatus.accepted;
      case 'rejected':
        return BookingStatus.rejected;
      case 'in_progress':
      case 'active':
        return BookingStatus.inProgress;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }
}


// ─── Live Location Model ─────────────────────────────────────────────────────
class LiveLocationModel {
  final String driverId;
  final double latitude;
  final double longitude;
  final double? bearing;
  final double? speed;
  final DateTime updatedAt;

  const LiveLocationModel({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    this.bearing,
    this.speed,
    required this.updatedAt,
  });

  factory LiveLocationModel.fromJson(Map<String, dynamic> json) {
    return LiveLocationModel(
      driverId: json['driver_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      bearing: (json['bearing'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'bearing': bearing,
        'speed': speed,
        'updated_at': updatedAt.toIso8601String(),
      };

  LiveLocation toEntity() {
    return LiveLocation(
      userId: driverId,
      lat: latitude,
      lng: longitude,
      heading: bearing ?? 0,
      speed: speed ?? 0,
      updatedAt: updatedAt,
    );
  }
}