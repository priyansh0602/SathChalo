// lib/presentation/providers/ride_search_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/maps_service.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/map_models.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/live_location.dart';
import '../providers/app_providers.dart';

// ── Passenger Search State ────────────────────────────────────
class RideSearchState {
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final List<PlaceSuggestion> suggestions;
  final List<Ride> matchingRides;
  final Ride? selectedRide;
  final Booking? activeBooking;
  final bool isSearching;
  final bool isLoadingSuggestions;
  final String? errorMessage;
  final SearchStep step;
  final LiveLocation? driverLiveLocation;
  final String vehicleType; // 'car' or 'bike'
  final int seatsNeeded;

  const RideSearchState({
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.pickupLocation,
    this.dropoffLocation,
    this.suggestions = const [],
    this.matchingRides = const [],
    this.selectedRide,
    this.activeBooking,
    this.isSearching = false,
    this.isLoadingSuggestions = false,
    this.errorMessage,
    this.step = SearchStep.idle,
    this.driverLiveLocation,
    this.vehicleType = 'car',
    this.seatsNeeded = 1,
  });

  bool get hasPickup => pickupLocation != null;
  bool get hasDropoff => dropoffLocation != null;
  bool get canSearch => hasPickup && hasDropoff;

  RideSearchState copyWith({
    String? pickupAddress,
    String? dropoffAddress,
    LatLng? pickupLocation,
    LatLng? dropoffLocation,
    List<PlaceSuggestion>? suggestions,
    List<Ride>? matchingRides,
    Ride? selectedRide,
    Booking? activeBooking,
    bool? isSearching,
    bool? isLoadingSuggestions,
    String? errorMessage,
    SearchStep? step,
    LiveLocation? driverLiveLocation,
    String? vehicleType,
    int? seatsNeeded,
    bool clearError = false,
    bool clearSelectedRide = false,
    bool clearBooking = false,
  }) {
    return RideSearchState(
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      suggestions: suggestions ?? this.suggestions,
      matchingRides: matchingRides ?? this.matchingRides,
      selectedRide: clearSelectedRide ? null : (selectedRide ?? this.selectedRide),
      activeBooking: clearBooking ? null : (activeBooking ?? this.activeBooking),
      isSearching: isSearching ?? this.isSearching,
      isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      step: step ?? this.step,
      driverLiveLocation: driverLiveLocation ?? this.driverLiveLocation,
      vehicleType: vehicleType ?? this.vehicleType,
      seatsNeeded: seatsNeeded ?? this.seatsNeeded,
    );
  }
}

enum SearchStep {
  idle,
  pickupInput,
  dropoffInput,
  searching,
  results,
  rideSelected,
  bookingPending,
  bookingAccepted,
  rideInProgress,
}

// ── Ride Search Notifier ──────────────────────────────────────
class RideSearchNotifier extends StateNotifier<RideSearchState> {
  final MapsService _maps;
  final SupabaseDataSource _db;
  Timer? _debounceTimer;
  RealtimeChannel? _bookingChannel;
  RealtimeChannel? _locationChannel;
  Timer? _ghostDriverTimer;
  String _sessionToken = '';

  RideSearchNotifier(this._maps, this._db)
      : super(const RideSearchState()) {
    _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
  }

  // ── Auto-fill pickup from GPS ──────────────────────────────
  Future<void> autoFillPickup(LatLng location) async {
    state = state.copyWith(isLoadingSuggestions: true);
    try {
      final address = await _maps.reverseGeocode(location.latitude, location.longitude);
      state = state.copyWith(
        pickupAddress: address,
        pickupLocation: location,
        isLoadingSuggestions: false,
      );
    } catch (e) {
      state = state.copyWith(
        pickupAddress: 'Current Location',
        pickupLocation: location,
        isLoadingSuggestions: false,
      );
    }
  }

  // ── Search for place suggestions ───────────────────────────
  Future<void> searchPlaces(String query, {bool isPickup = true}) async {
    if (isPickup) {
      state = state.copyWith(
          pickupAddress: query, step: SearchStep.pickupInput);
    } else {
      state = state.copyWith(
          dropoffAddress: query, step: SearchStep.dropoffInput);
    }

    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      state = state.copyWith(suggestions: []);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      state = state.copyWith(isLoadingSuggestions: true);
      try {
        final suggestions = await _maps.getPlaceSuggestions(
          input: query,
          biasLocation: state.pickupLocation,
        );
        state = state.copyWith(
            suggestions: suggestions, isLoadingSuggestions: false);
      } catch (e) {
        state = state.copyWith(
            isLoadingSuggestions: false, suggestions: []);
      }
    });
  }

  void setVehicleType(String type) => state = state.copyWith(vehicleType: type);
  void setSeatsNeeded(int count) => state = state.copyWith(seatsNeeded: count);

  // ── Select a suggestion ────────────────────────────────────
  Future<void> selectSuggestion(
      PlaceSuggestion suggestion, bool isPickup) async {
    state = state.copyWith(isLoadingSuggestions: true, suggestions: []);
    try {
      final latLng = await _maps.getPlaceLatLng(suggestion.placeId);
      if (latLng == null) {
        state = state.copyWith(
            isLoadingSuggestions: false,
            errorMessage: 'Could not get location');
        return;
      }

      if (isPickup) {
        state = state.copyWith(
          pickupAddress: suggestion.mainText,
          pickupLocation: latLng,
          isLoadingSuggestions: false,
          step: state.hasDropoff ? SearchStep.searching : SearchStep.dropoffInput,
        );
      } else {
        state = state.copyWith(
          dropoffAddress: suggestion.mainText,
          dropoffLocation: latLng,
          isLoadingSuggestions: false,
          step: SearchStep.searching,
        );
      }

      // Auto-search when both are filled
      if (state.canSearch && (state.step == SearchStep.searching || state.step == SearchStep.results)) {
        await findRides();
      }
    } catch (e) {
      state = state.copyWith(
          isLoadingSuggestions: false,
          errorMessage: e.toString());
    }
  }

  // ── Main search: find 400m corridor matching rides ─────────
  Future<void> findRides() async {
    if (!state.canSearch) return;
    state = state.copyWith(isSearching: true, step: SearchStep.searching);

    try {
      final results = await _db.findMatchingRides(
        pickupLat: state.pickupLocation!.latitude,
        pickupLng: state.pickupLocation!.longitude,
        dropoffLat: state.dropoffLocation!.latitude,
        dropoffLng: state.dropoffLocation!.longitude,
        vehicleType: state.vehicleType,
        seatsNeeded: state.vehicleType == 'bike' ? 1 : state.seatsNeeded,
      );

      final rides = results
          .map((r) => r.toEntity())
          .toList();

      state = state.copyWith(
        matchingRides: rides,
        isSearching: false,
        step: SearchStep.results,
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: 'Search failed: ${e.toString()}',
        step: SearchStep.results,
      );
    }
  }

  // ── Select a ride ──────────────────────────────────────────
  void selectRide(Ride ride) {
    state = state.copyWith(
        selectedRide: ride, step: SearchStep.rideSelected);
  }

  // ── Book a ride ────────────────────────────────────────────
  Future<void> bookRide() async {
    final ride = state.selectedRide;
    if (ride == null) return;

    state = state.copyWith(isSearching: true);
    try {
      final result = await _db.createBooking(
        rideId: ride.id,
        passengerId: _db.currentUserId!,
        pickupAddress: state.pickupAddress,
        dropoffAddress: state.dropoffAddress,
        pickupLat: state.pickupLocation!.latitude,
        pickupLng: state.pickupLocation!.longitude,
        dropoffLat: state.dropoffLocation!.latitude,
        dropoffLng: state.dropoffLocation!.longitude,
        seatsRequested: state.vehicleType == 'bike' ? 1 : state.seatsNeeded,
        vehicleType: state.vehicleType,
      );

      final booking = result.toEntity();
      state = state.copyWith(
        activeBooking: booking,
        isSearching: false,
        step: SearchStep.bookingPending,
      );

      // Subscribe to booking updates
      _subscribeToBookingUpdates(booking.id, ride.driverId);
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: 'Booking failed: ${e.toString()}',
      );
    }
  }

  Future<void> cancelBooking() async {
    final bookingId = state.activeBooking?.id;
    if (bookingId == null) return;
    await _db.cancelBooking(bookingId);
    state = state.copyWith(step: SearchStep.results, clearBooking: true);
    _cleanupSubscriptions();
  }

  // ── Listen for driver's accept/reject ─────────────────────
  void _subscribeToBookingUpdates(
      String bookingId, String driverId) {
    _bookingChannel = _db.subscribeToPassengerBooking(
      passengerId: _db.currentUserId!,
      onUpdate: (booking) {
        if (booking.id != bookingId) return;
        final newStatus = booking.status;
        if (newStatus == 'accepted') {
          state = state.copyWith(step: SearchStep.bookingAccepted);
          // Start watching driver's live location
          _watchDriverLocation(driverId, bookingId);
        } else if (newStatus == 'in_progress') {
          state = state.copyWith(step: SearchStep.rideInProgress);
        } else if (newStatus == 'rejected' ||
            newStatus == 'cancelled') {
          state = state.copyWith(
            step: SearchStep.results,
            errorMessage:
                newStatus == 'rejected' ? 'Driver rejected your request' : null,
            clearBooking: true,
          );
          _cleanupSubscriptions();
        }
      },
    );
  }

  void _watchDriverLocation(String driverId, String rideId) {
    _locationChannel = _db.subscribeToDriverLocation(
      driverId: driverId,
      onUpdate: (locationModel) {
        state = state.copyWith(driverLiveLocation: locationModel.toEntity());
      },
    );

    // Ghost Driver Cleanup Check: every 15s check if location is older than 120s
    _ghostDriverTimer?.cancel();
    _ghostDriverTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final loc = state.driverLiveLocation;
      if (loc != null) {
        final staleThreshold = DateTime.now().subtract(const Duration(seconds: 120));
        if (loc.updatedAt.isBefore(staleThreshold)) {
          // Remove driver from Live Map
          state = state.copyWith(driverLiveLocation: null);
        }
      }
    });
  }

  void _cleanupSubscriptions() {
    if (_bookingChannel != null) {
      _db.removeChannel(_bookingChannel!);
      _bookingChannel = null;
    }
    if (_locationChannel != null) {
      _db.removeChannel(_locationChannel!);
      _locationChannel = null;
    }
    _ghostDriverTimer?.cancel();
    _ghostDriverTimer = null;
  }

  void reset() {
    _cleanupSubscriptions();
    _debounceTimer?.cancel();
    state = const RideSearchState();
  }

  @override
  void dispose() {
    _cleanupSubscriptions();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final rideSearchProvider =
    StateNotifierProvider<RideSearchNotifier, RideSearchState>((ref) {
  return RideSearchNotifier(
    ref.read(mapsServiceProvider),
    ref.read(supabaseDataSourceProvider),
  );
});
