// lib/domain/entities/live_location.dart
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LiveLocation extends Equatable {
  final String userId;
  final String? rideId;
  final double lat;
  final double lng;
  final double heading;
  final double speed;
  final DateTime updatedAt;

  const LiveLocation({
    required this.userId,
    this.rideId,
    required this.lat,
    required this.lng,
    this.heading = 0,
    this.speed = 0,
    required this.updatedAt,
  });

  LatLng get latLng => LatLng(lat, lng);

  @override
  List<Object?> get props => [userId, lat, lng, updatedAt];
}
