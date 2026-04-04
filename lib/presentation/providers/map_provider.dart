// lib/presentation/providers/map_provider.dart
import 'dart:async';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../data/datasources/maps_service.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/map_models.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/live_location.dart';
import 'app_providers.dart';

// ── Map State ─────────────────────────────────────────────────
class MapState {
  final LatLng? currentLocation;
  final bool isLoading;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final String? errorMessage;
  final GoogleMapController? mapController;

  final String? lastMapError;
  final bool isMapReady;

  const MapState({
    this.currentLocation,
    this.isLoading = false,
    this.markers = const {},
    this.polylines = const {},
    this.circles = const {},
    this.errorMessage,
    this.mapController,
    this.lastMapError,
    this.isMapReady = false,
  });

  MapState copyWith({
    LatLng? currentLocation,
    bool? isLoading,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    Set<Circle>? circles,
    String? errorMessage,
    GoogleMapController? mapController,
    String? lastMapError,
    bool? isMapReady,
    bool clearError = false,
  }) {
    return MapState(
      currentLocation: currentLocation ?? this.currentLocation,
      isLoading: isLoading ?? this.isLoading,
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      circles: circles ?? this.circles,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      mapController: mapController ?? this.mapController,
      lastMapError: lastMapError ?? this.lastMapError,
      isMapReady: isMapReady ?? this.isMapReady,
    );
  }
}

// ── Map Notifier ──────────────────────────────────────────────
class MapNotifier extends StateNotifier<MapState> {
  final MapsService _locationService;
  final SupabaseDataSource _db;
  StreamSubscription<Position>? _locationSub;
  Timer? _locationUploadTimer;
  final Map<String, BitmapDescriptor> _markerIcons = {};

  MapNotifier(this._locationService, this._db) : super(const MapState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadMarkerIcons();
    await initLocation();
  }

  // ── Load custom marker icons ───────────────────────────────
  Future<void> _loadMarkerIcons() async {
    try {
      _markerIcons['car'] = await _createCarMarker();
      _markerIcons['pickup'] = await _createDotMarker(AppTheme.accentGreen);
      _markerIcons['dropoff'] = await _createDotMarker(AppTheme.errorRed);
      _markerIcons['user'] = await _createDotMarker(AppTheme.accentBlue);
    } catch (_) {}
  }

  Future<BitmapDescriptor> _createCarMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(48, 48);

    // Draw car icon circle
    final bgPaint = Paint()..color = AppTheme.accentGreen;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), 22, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🚗',
        style: TextStyle(fontSize: 22),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
        size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createDotMarker(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(32, 32);

    // Outer ring
    final outerPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(16, 16), 14, outerPaint);

    // Inner dot
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(16, 16), 8, innerPaint);

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(16, 16), 8, borderPaint);

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  // ── Initialize location ────────────────────────────────────
  Future<void> initLocation() async {
    state = state.copyWith(isLoading: true);
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      final latLng = LatLng(position.latitude, position.longitude);
      state = state.copyWith(
        currentLocation: latLng,
        isLoading: false,
      );
      _animateToLocation(latLng);
    } else {
      // Default to Delhi if location unavailable
      const delhi = LatLng(28.6139, 77.2090);
      state = state.copyWith(currentLocation: delhi, isLoading: false);
    }
  }

  // ── Set map controller ─────────────────────────────────────
  Future<void> setMapController(GoogleMapController controller) async {
    state = state.copyWith(mapController: controller);
    // Give Mali/Android driver time to acquire surface buffer
    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(isMapReady: true);
    
    if (state.currentLocation != null) {
      _animateToLocation(state.currentLocation!);
    }
  }

  void _animateToLocation(LatLng location, {double zoom = 15}) {
    state.mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: zoom),
      ),
    );
  }

  void showActiveRide(Ride ride) {
    final points = _locationService.decodePolyline(ride.routePolyline);
    if (points.isNotEmpty) {
      showRoute(
        points: points,
        pickup: LatLng(ride.origin.latitude, ride.origin.longitude),
        dropoff: LatLng(ride.destination.latitude, ride.destination.longitude),
        showCorridor: true,
      );
    }
  }

  // ── Show route polyline on map ─────────────────────────────
  void showRoute({
    required List<LatLng> points,
    required LatLng pickup,
    required LatLng dropoff,
    String routeId = 'main_route',
    Color color = AppTheme.accentGreen,
    bool showCorridor = false,
  }) {
    final newPolylines = <Polyline>{};
    final newMarkers = <Marker>{};
    final newCircles = <Circle>{};

    // Main route polyline
    newPolylines.add(Polyline(
      polylineId: PolylineId(routeId),
      points: points,
      color: color,
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    ));

    // Pickup marker
    newMarkers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: pickup,
      icon: _markerIcons['pickup'] ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Pickup'),
    ));

    // Dropoff marker
    newMarkers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: dropoff,
      icon: _markerIcons['dropoff'] ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: 'Drop-off'),
    ));

    // 400m corridor circles at key points (visual indicator)
    if (showCorridor) {
      for (int i = 0; i < points.length; i += points.length ~/ 10 + 1) {
        newCircles.add(Circle(
          circleId: CircleId('corridor_$i'),
          center: points[i],
          radius: AppConstants.matchRadiusMeters.toDouble(),
          fillColor: AppTheme.accentGreen.withOpacity(0.05),
          strokeColor: AppTheme.accentGreen.withOpacity(0.2),
          strokeWidth: 1,
        ));
      }
    }

    state = state.copyWith(
      polylines: newPolylines,
      markers: {...state.markers, ...newMarkers},
      circles: newCircles,
    );

    // Fit camera to route
    if (!state.isMapReady) return;
    final allPoints = [...points, pickup, dropoff];
    final bounds = _boundsFromPoints(allPoints);
    state.mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  // ── Show matching drivers on map ───────────────────────────
  void showDriverMarkers(List<Ride> rides) {
    final driverMarkers = rides.map((ride) {
      return Marker(
        markerId: MarkerId('driver_${ride.id}'),
        position: ride.origin,
        icon: _markerIcons['car'] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: ride.driverName,
          snippet:
              '${ride.availableSeats} seats • ${ride.priceDisplay}',
        ),
      );
    }).toSet();

    // Preserve pickup/dropoff markers
    final existing = state.markers
        .where((m) =>
            m.markerId.value == 'pickup' ||
            m.markerId.value == 'dropoff')
        .toSet();

    state = state.copyWith(markers: {...existing, ...driverMarkers});
  }

  // ── Live car marker update (smooth animation) ─────────────
  void updateDriverLocation(String driverId, LiveLocation location) {
    final markerId = MarkerId('live_driver_$driverId');
    final newMarker = Marker(
      markerId: markerId,
      position: location.latLng,
      rotation: location.heading,
      flat: true,
      icon: _markerIcons['car'] ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      anchor: const Offset(0.5, 0.5),
    );

    final updated = state.markers
        .where((m) => m.markerId.value != markerId.value)
        .toSet();
    updated.add(newMarker);
    state = state.copyWith(markers: updated);
  }

  // ── Start live location upload (driver) ───────────────────
  void startLocationUpload(String? rideId) {
    _locationService.requestLocationPermission();
    _locationSub = _locationService.getLocationStream().listen((pos) async {
      try {
        await _db.upsertLiveLocation(
          driverId: _db.currentUserId!,
          latitude: pos.latitude,
          longitude: pos.longitude,
          bearing: pos.heading,
          speed: pos.speed,
        );
      } catch (e) {
        debugPrint('Location upload error: $e');
      }
    });
  }

  void stopLocationUpload() {
    _locationSub?.cancel();
    _locationSub = null;
  }

  // ── Clear map ─────────────────────────────────────────────
  void clearMap() {
    state = state.copyWith(
      markers: const {},
      polylines: const {},
      circles: const {},
    );
  }

  void addUserLocationMarker(LatLng location) {
    final marker = Marker(
      markerId: const MarkerId('user_location'),
      position: location,
      icon: _markerIcons['user'] ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'You are here'),
    );
    state = state.copyWith(
      markers: {...state.markers, marker},
    );
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;
    for (final p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  @override
  void dispose() {
    stopLocationUpload();
    super.dispose();
  }
}

final mapProvider =
    StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier(
    ref.read(mapsServiceProvider),
    ref.read(supabaseDataSourceProvider),
  );
});
