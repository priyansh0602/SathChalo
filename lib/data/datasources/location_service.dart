// lib/data/datasources/location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;
  final StreamController<Position> _locationController =
      StreamController<Position>.broadcast();

  Stream<Position> get locationStream => _locationController.stream;

  // ── Request Permission ─────────────────────────────────────
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<bool> isPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // ── Get Current Position ───────────────────────────────────
  Future<Position?> getCurrentPosition() async {
    final granted = await requestPermission();
    if (!granted) return null;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Future<LatLng?> getCurrentLatLng() async {
    final pos = await getCurrentPosition();
    if (pos == null) return null;
    return LatLng(pos.latitude, pos.longitude);
  }

  // ── Start Continuous Location Updates ─────────────────────
  void startTracking({
    int intervalSeconds = 3,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: 5, // metres
        timeLimit: Duration(seconds: intervalSeconds * 2),
      ),
    ).listen(
      (position) => _locationController.add(position),
      onError: (e) => print('Location stream error: $e'),
    );
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  double distanceBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  void dispose() {
    stopTracking();
    _locationController.close();
  }
}
