// lib/presentation/providers/driver_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/maps_service.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/map_models.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/live_location.dart' as ent;
import 'app_providers.dart';
import 'map_provider.dart';

class DriverState {
  final String originAddress;
  final String destinationAddress;
  final LatLng? originLocation;
  final LatLng? destinationLocation;
  final List<RouteOption> routeOptions;
  final RouteOption? selectedRoute;
  final List<PlaceSuggestion> suggestions;
  final Ride? activeRide;
  final List<Booking> rideBookings;
  final int availableSeats;
  final double pricePerSeat;
  final DateTime? departureTime;
  final bool isLoading;
  final bool isLoadingSuggestions;
  final String? errorMessage;
  final DriverStep step;
  final bool isOnRide;
  final List<Map<String, dynamic>> passengersOnRoute;

  const DriverState({
    this.originAddress = '',
    this.destinationAddress = '',
    this.originLocation,
    this.destinationLocation,
    this.routeOptions = const [],
    this.selectedRoute,
    this.suggestions = const [],
    this.activeRide,
    this.rideBookings = const [],
    this.availableSeats = 3,
    this.pricePerSeat = 0,
    this.departureTime,
    this.isLoading = false,
    this.isLoadingSuggestions = false,
    this.errorMessage,
    this.step = DriverStep.idle,
    this.isOnRide = false,
    this.passengersOnRoute = const [],
  });

  DriverState copyWith({
    String? originAddress,
    String? destinationAddress,
    LatLng? originLocation,
    LatLng? destinationLocation,
    List<RouteOption>? routeOptions,
    RouteOption? selectedRoute,
    List<PlaceSuggestion>? suggestions,
    Ride? activeRide,
    List<Booking>? rideBookings,
    int? availableSeats,
    double? pricePerSeat,
    DateTime? departureTime,
    bool? isLoading,
    bool? isLoadingSuggestions,
    String? errorMessage,
    DriverStep? step,
    bool? isOnRide,
    List<Map<String, dynamic>>? passengersOnRoute,
    bool clearError = false,
  }) {
    return DriverState(
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      originLocation: originLocation ?? this.originLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      routeOptions: routeOptions ?? this.routeOptions,
      selectedRoute: selectedRoute ?? this.selectedRoute,
      suggestions: suggestions ?? this.suggestions,
      activeRide: activeRide ?? this.activeRide,
      rideBookings: rideBookings ?? this.rideBookings,
      availableSeats: availableSeats ?? this.availableSeats,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      departureTime: departureTime ?? this.departureTime,
      isLoading: isLoading ?? this.isLoading,
      isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      step: step ?? this.step,
      isOnRide: isOnRide ?? this.isOnRide,
      passengersOnRoute: passengersOnRoute ?? this.passengersOnRoute,
    );
  }
}

enum DriverStep {
  idle,
  destinationInput,
  fetchingRoutes,
  routeSelection,
  rideDetails,
  ridePublished,
  activeRide,
  otpEntry,
}

// ── Driver Notifier ───────────────────────────────────────────
class DriverNotifier extends StateNotifier<DriverState> {
  final MapsService _maps;
  final SupabaseDataSource _db;
  Timer? _debounceTimer;
  RealtimeChannel? _bookingChannel;
  Timer? _proximityCheckTimer;
  Timer? _passengersRefreshTimer;
  Timer? _deviationCheckTimer;
  final LatLng? Function() _getCurrentLocation;

  DriverNotifier(this._maps, this._db, this._getCurrentLocation) : super(const DriverState());

  void syncRide(Ride ride, [List<Map<String, dynamic>>? passengers]) {
    state = state.copyWith(
      activeRide: ride,
      originAddress: ride.originAddress,
      destinationAddress: ride.destinationAddress,
      originLocation: LatLng(ride.origin.latitude, ride.origin.longitude),
      destinationLocation: LatLng(ride.destination.latitude, ride.destination.longitude),
      availableSeats: ride.availableSeats,
      pricePerSeat: ride.pricePerSeat,
      isOnRide: true,
      passengersOnRoute: passengers ?? [],
      step: DriverStep.activeRide,
    );
    _subscribeToBookings(ride.id);
    _startDeviationCheck();
    _startPassengersRefresh(ride.id);
    _loadBookings();
  }

  void _startPassengersRefresh(String rideId) {
    _passengersRefreshTimer?.cancel();
    _passengersRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final passengers = await _db.getPassengersOnRoute(rideId: rideId);
        if (mounted) {
          state = state.copyWith(passengersOnRoute: passengers);
        }
      } catch (_) {}
    });
  }


  // ── Auto-fill origin from GPS ──────────────────────────────
  Future<void> autoFillOrigin(LatLng location) async {
    try {
      final address = await _maps.reverseGeocode(
        location.latitude,
        location.longitude,
      );
      state = state.copyWith(
        originAddress: address,
        originLocation: location,
      );
    } catch (_) {
      state = state.copyWith(
        originAddress: 'Current Location',
        originLocation: location,
      );
    }
  }

  // ── Search destination ─────────────────────────────────────
  Future<void> searchDestination(String query) async {
    state = state.copyWith(
        destinationAddress: query, step: DriverStep.destinationInput);

    _debounceTimer?.cancel();
    if (query.length < 2) {
      state = state.copyWith(suggestions: []);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      state = state.copyWith(isLoadingSuggestions: true);
      try {
        final suggestions = await _maps.getPlaceSuggestions(
          input: query,
          biasLocation: state.originLocation,
        );
        state = state.copyWith(
            suggestions: suggestions, isLoadingSuggestions: false);
      } catch (_) {
        state = state.copyWith(
            suggestions: [], isLoadingSuggestions: false);
      }
    });
  }

  // ── Select destination & fetch routes ─────────────────────
  Future<void> selectDestination(PlaceSuggestion suggestion) async {
    state = state.copyWith(
      isLoading: true,
      suggestions: [],
      destinationAddress: suggestion.mainText,
      step: DriverStep.fetchingRoutes,
    );

    try {
      final latLng = await _maps.getPlaceLatLng(suggestion.placeId);
      if (latLng == null) throw Exception('Could not get coordinates');

      state = state.copyWith(destinationLocation: latLng);

      final routes = await _maps.getRouteOptions(
        origin: state.originLocation!,
        destination: latLng,
      );

      state = state.copyWith(
        routeOptions: routes,
        selectedRoute: routes.isNotEmpty ? routes.first : null,
        isLoading: false,
        step: DriverStep.routeSelection,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        step: DriverStep.idle,
      );
    }
  }

  void selectRoute(RouteOption route) {
    state = state.copyWith(selectedRoute: route);
  }

  void confirmRoute() {
    state = state.copyWith(step: DriverStep.rideDetails);
  }

  void setSeats(int seats) => state = state.copyWith(availableSeats: seats);
  void setPrice(double price) => state = state.copyWith(pricePerSeat: price);
  void setDepartureTime(DateTime time) =>
      state = state.copyWith(departureTime: time);

  // ── Publish ride ───────────────────────────────────────────
  Future<void> publishRide() async {
    final route = state.selectedRoute;
    if (route == null ||
        state.originLocation == null ||
        state.destinationLocation == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final driverId = _db.currentUserId!;

      // CLEANUP: Cancel any phantom duplicate rides before creating a new one!
      await _db.cancelAllMyPreviousRides(driverId);

      final ride = await _db.createRide(
        driverId: driverId,
        originAddress: state.originAddress,
        destinationAddress: state.destinationAddress,
        originLat: state.originLocation!.latitude,
        originLng: state.originLocation!.longitude,
        destinationLat: state.destinationLocation!.latitude,
        destinationLng: state.destinationLocation!.longitude,
        routePolyline: route.encodedPolyline,
        availableSeats: state.availableSeats,
        departureTime: state.departureTime ??
            DateTime.now().add(const Duration(minutes: 15)),
        pricePerSeat: state.pricePerSeat,
      );

      state = state.copyWith(
        activeRide: ride.toEntity(),
        isLoading: false,
        step: DriverStep.ridePublished,
      );

      // Subscribe to incoming bookings
      _subscribeToBookings(ride.id);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to publish: ${e.toString()}',
      );
    }
  }

  void _subscribeToBookings(String rideId) {
    _bookingChannel = _db.subscribeToBookingUpdates(
      rideId: rideId,
      onUpdate: (bookingModel, deletedId) {
        if (deletedId != null) {
          // Remove deleted booking from UI immediately
          final updated = state.rideBookings.where((b) => b.id != deletedId).toList();
          state = state.copyWith(rideBookings: updated);
        } else if (bookingModel != null) {
          final booking = bookingModel.toDomain();
          final existingIdx =
              state.rideBookings.indexWhere((b) => b.id == booking.id);
          if (existingIdx >= 0) {
            final updated = [...state.rideBookings];
            updated[existingIdx] = booking;
            state = state.copyWith(rideBookings: updated);
          } else {
            state = state.copyWith(
                rideBookings: [...state.rideBookings, booking]);
          }
        }
      },
    );
  }

  // ── Accept a booking ───────────────────────────────────────
  Future<void> acceptBooking(String bookingId) async {
    // Check if there are available seats before accepting
    if (state.activeRide == null) return;
    final currentSeats = state.availableSeats;
    final acceptedCount = state.rideBookings.where((b) => b.isAccepted || b.isActive).length;
    if (acceptedCount >= currentSeats) {
      state = state.copyWith(errorMessage: 'No seats available');
      return;
    }

    await _db.updateBookingStatus(
      bookingId: bookingId,
      status: 'accepted',
    );
    // Decrement seat count in Supabase
    await _db.decrementAvailableSeats(state.activeRide!.id);
    state = state.copyWith(availableSeats: currentSeats > 0 ? currentSeats - 1 : 0);
    _loadBookings();
  }

  Future<void> rejectBooking(String bookingId) async {
    await _db.updateBookingStatus(
      bookingId: bookingId,
      status: 'rejected',
    );
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (state.activeRide == null) return;
    final rawBookings = await _db.getBookingsByRide(state.activeRide!.id);
    // Map to domain Booking list
    final bookings = rawBookings
        .map<Booking>((b) => b.toDomain())
        .toList();
    state = state.copyWith(rideBookings: bookings);
  }

  // ── Verify OTP ─────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyOtp(
      String bookingId, String otp) async {
    return await _db.verifyOtpAndStart(
      bookingId: bookingId,
      otp: otp,
    );
  }

  // ── Check if driver is near pickup ─────────────────────────
  Future<bool> checkProximityToPickup(LatLng pickupLocation) async {
    final result = await _db.checkDriverProximity(
      rideId: state.activeRide?.id ?? '',
      lat: pickupLocation.latitude,
      lng: pickupLocation.longitude,
    );
    return result ?? false;
  }

  // ── Start active ride ──────────────────────────────────────
  void startRide() {
    state = state.copyWith(isOnRide: true, step: DriverStep.activeRide);
    _startDeviationCheck();
  }

  void _startDeviationCheck() {
    _deviationCheckTimer?.cancel();
    _deviationCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (state.activeRide == null) return;
      final currentLoc = _getCurrentLocation();
      if (currentLoc == null) return;

      final polylineStr = state.activeRide!.routePolyline;
      final points = _maps.decodePolyline(polylineStr);
      final isNear = _maps.isPointNearPolyline(
        point: currentLoc,
        polylinePoints: points,
        radiusMeters: 500,
      );

      if (!isNear) {
        // Driver deviated more than 500m!
        try {
          final destLatLng = LatLng(
            state.activeRide!.destination.latitude,
            state.activeRide!.destination.longitude,
          );
          final newRoutes = await _maps.getRouteOptions(
            origin: currentLoc,
            destination: destLatLng,
          );
          if (newRoutes.isNotEmpty) {
            final bestRoute = newRoutes.first;
            // Update the DB
            await _db.client.from('rides').update({
              'route_polyline': bestRoute.encodedPolyline,
            }).eq('id', state.activeRide!.id);
            // Update local state
            final updatedRide = state.activeRide!.copyWith(routePolyline: bestRoute.encodedPolyline);
            state = state.copyWith(activeRide: updatedRide, selectedRoute: bestRoute);
          }
        } catch (e) {
          // Silent fail on deviation check
        }
      }
    });
  }

  // ── End ride ──────────────────────────────────────────────
  Future<void> endRide() async {
    if (state.activeRide == null) return;
    await _db.updateRideStatus(rideId: state.activeRide!.id, status: 'completed');
    _cleanupSubscriptions();
    state = const DriverState();
  }

  void _cleanupSubscriptions() {
    if (_bookingChannel != null) {
      _db.removeChannel(_bookingChannel!);
      _bookingChannel = null;
    }
    _proximityCheckTimer?.cancel();
    _deviationCheckTimer?.cancel();
  }

  void reset() {
    _cleanupSubscriptions();
    _debounceTimer?.cancel();
    state = const DriverState();
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final driverProvider =
    StateNotifierProvider<DriverNotifier, DriverState>((ref) {
  final maps = ref.watch(mapsServiceProvider);
  final db = ref.watch(supabaseDataSourceProvider);
  final notifier = DriverNotifier(maps, db, () => ref.read(mapProvider).currentLocation);

  return notifier;
});