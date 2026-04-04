import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/datasources/kyc_service.dart';
import '../../data/datasources/maps_service.dart';
import '../../data/repositories/ride_repository_impl.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/map_models.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'map_provider.dart';

// ─── Services ───────────────────────────────────────
final supabaseDataSourceProvider = Provider<SupabaseDataSource>((ref) {
  return SupabaseDataSource();
});

final mapsServiceProvider = Provider<MapsService>((ref) {
  return MapsService();
});

// ─── Ride Repository ──────────────────────────────────────────────────────────
final rideRepositoryProvider = Provider<RideRepositoryImpl>((ref) {
  return RideRepositoryImpl(
    supabase: ref.read(supabaseDataSourceProvider),
    mapsService: ref.read(mapsServiceProvider),
  );
});

// ─── Auth / Profile ───────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<ProfileModel?> {
  final SupabaseDataSource _supabase;

  AuthNotifier(this._supabase) : super(null) {
    _init();
  }

  void _init() {
    _supabase.authStateStream.listen((authState) async {
      final user = authState.session?.user;
      if (user != null) {
        final profile = await _supabase.getProfile(user.id);
        state = profile;
      } else {
        state = null;
      }
    });
  }

  Future<void> mockLogin({
    required String name,
    required String phone,
  }) async {
    final profile = await _supabase.mockLogin(name: name, phone: phone);
    state = profile;
  }

  Future<void> loginWithAadhaarDetails({
    required String name,
    required String phone,
    required String gender,
    required String dob,
    required String lastFour,
  }) async {
    final profile = await _supabase.getOrCreateProfileWithAadhaar(
      name: name,
      phone: phone,
      gender: gender,
      dob: dob,
      lastFour: lastFour,
    );
    state = profile;
  }

  Future<void> updateDriverMode(bool isDriver) async {
    if (state == null) return;
    final updated = await _supabase.updateProfile(
      userId: state!.id,
      isDriver: isDriver,
    );
    state = updated;
  }

  Future<void> updateVehicleInfo({
    required String vehicleNumber,
    required String vehicleModel,
    required String vehicleColor,
  }) async {
    if (state == null) return;
    final updated = await _supabase.updateProfile(
      userId: state!.id,
      vehicleNumber: vehicleNumber,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      isDriver: true,
    );
    state = updated;
  }

  Future<void> updateAadhaarDetails({
    required String aadhaarLastFour,
    required String gender,
    required String dob,
  }) async {
    if (state == null) return;
    final updated = await _supabase.updateAadhaarDetails(
      userId: state!.id,
      aadhaarLastFour: aadhaarLastFour,
      gender: gender,
      dob: dob,
    );
    state = updated;
  }

  void logout() {
    _supabase.signOut();
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, ProfileModel?>((ref) {
  return AuthNotifier(ref.read(supabaseDataSourceProvider));
});

// ─── KYC Service ──────────────────────────────────────────────────────────────
final kycServiceProvider = Provider<KycService>((ref) => KycService());

// ─── Current Location ─────────────────────────────────────────────────────────
class LocationNotifier extends StateNotifier<Position?> {
  final MapsService _mapsService;
  StreamSubscription<Position>? _sub;

  LocationNotifier(this._mapsService) : super(null) {
    _fetchInitial();
  }

  Future<void> _fetchInitial() async {
    final pos = await _mapsService.getCurrentPosition();
    if (pos != null) state = pos;
    _startStream();
  }

  void _startStream() {
    _sub = _mapsService.getLocationStream().listen((pos) {
      state = pos;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, Position?>((ref) {
  return LocationNotifier(ref.read(mapsServiceProvider));
});

final currentLatLngProvider = Provider<LatLng?>((ref) {
  final pos = ref.watch(locationProvider);
  if (pos == null) return null;
  return LatLng(pos.latitude, pos.longitude);
});

// ─── Home Map State ───────────────────────────────────────────────────────────
class HomeMapState {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool isLoading;
  final String? error;

  const HomeMapState({
    this.markers = const {},
    this.polylines = const {},
    this.isLoading = false,
    this.error,
  });

  HomeMapState copyWith({
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    bool? isLoading,
    String? error,
  }) {
    return HomeMapState(
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HomeMapNotifier extends StateNotifier<HomeMapState> {
  final MapsService _maps;

  HomeMapNotifier(this._maps) : super(const HomeMapState());

  void addMarker(Marker marker) {
    state = state.copyWith(
        markers: {...state.markers}..removeWhere(
            (m) => m.markerId == marker.markerId)
          ..add(marker));
  }

  void setPolylines(Set<Polyline> polylines) {
    state = state.copyWith(polylines: polylines);
  }

  void clearAll() {
    state = const HomeMapState();
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }
}

final homeMapProvider =
    StateNotifierProvider<HomeMapNotifier, HomeMapState>((ref) {
  return HomeMapNotifier(ref.read(mapsServiceProvider));
});

// ─── Search State ─────────────────────────────────────────────────────────────
class SearchState {
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng? pickupLatLng;
  final LatLng? dropoffLatLng;
  final List<PlaceSuggestion> suggestions;
  final bool isSearchingPickup;
  final bool isLoading;
  final String vehicleType;
  final int seatsNeeded;

  const SearchState({
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.pickupLatLng,
    this.dropoffLatLng,
    this.suggestions = const [],
    this.isSearchingPickup = true,
    this.isLoading = false,
    this.vehicleType = 'car',
    this.seatsNeeded = 1,
  });

  SearchState copyWith({
    String? pickupAddress,
    String? dropoffAddress,
    LatLng? pickupLatLng,
    LatLng? dropoffLatLng,
    List<PlaceSuggestion>? suggestions,
    bool? isSearchingPickup,
    bool? isLoading,
    String? vehicleType,
    int? seatsNeeded,
  }) {
    return SearchState(
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      pickupLatLng: pickupLatLng ?? this.pickupLatLng,
      dropoffLatLng: dropoffLatLng ?? this.dropoffLatLng,
      suggestions: suggestions ?? this.suggestions,
      isSearchingPickup: isSearchingPickup ?? this.isSearchingPickup,
      isLoading: isLoading ?? this.isLoading,
      vehicleType: vehicleType ?? this.vehicleType,
      seatsNeeded: seatsNeeded ?? this.seatsNeeded,
    );
  }

  bool get isComplete => pickupLatLng != null && dropoffLatLng != null;
}

class SearchNotifier extends StateNotifier<SearchState> {
  final MapsService _maps;

  SearchNotifier(this._maps) : super(const SearchState());

  Future<void> initPickupFromLocation(LatLng position) async {
    state = state.copyWith(isLoading: true);
    final address = await _maps.reverseGeocode(
        position.latitude, position.longitude);
    state = state.copyWith(
      pickupAddress: address,
      pickupLatLng: position,
      isLoading: false,
    );
  }

  void setSearchingPickup(bool value) {
    state = state.copyWith(isSearchingPickup: value, suggestions: []);
  }

  Future<void> searchPlaces(String query, {LatLng? biasLocation}) async {
    if (query.length < 2) {
      state = state.copyWith(suggestions: []);
      return;
    }
    state = state.copyWith(isLoading: true);
    final suggestions = await _maps.getPlaceSuggestions(
      input: query,
      biasLocation: biasLocation,
    );
    state = state.copyWith(suggestions: suggestions, isLoading: false);
  }

  Future<void> selectSuggestion(PlaceSuggestion suggestion) async {
    state = state.copyWith(isLoading: true, suggestions: []);
    final latLng = await _maps.getPlaceLatLng(suggestion.placeId);
    if (state.isSearchingPickup) {
      state = state.copyWith(
        pickupAddress: suggestion.fullText,
        pickupLatLng: latLng,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        dropoffAddress: suggestion.fullText,
        dropoffLatLng: latLng,
        isLoading: false,
      );
    }
  }

  void setVehicleType(String type) => state = state.copyWith(vehicleType: type);
  void setSeatsNeeded(int count) => state = state.copyWith(seatsNeeded: count);

  void clearDropoff() {
    state = state.copyWith(dropoffAddress: '', dropoffLatLng: null);
  }

  void reset() {
    state = const SearchState();
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.read(mapsServiceProvider));
});

// ─── Ride Results ─────────────────────────────────────────────────────────────
class RideResultsState {
  final List<RideModel> rides;
  final bool isLoading;
  final String? error;
  final RideModel? selectedRide;

  const RideResultsState({
    this.rides = const [],
    this.isLoading = false,
    this.error,
    this.selectedRide,
  });

  RideResultsState copyWith({
    List<RideModel>? rides,
    bool? isLoading,
    String? error,
    RideModel? selectedRide,
  }) {
    return RideResultsState(
      rides: rides ?? this.rides,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedRide: selectedRide ?? this.selectedRide,
    );
  }
}

class RideResultsNotifier extends StateNotifier<RideResultsState> {
  final RideRepositoryImpl _repo;

  RideResultsNotifier(this._repo) : super(const RideResultsState());

  Future<void> searchRides({
    required LatLng pickup,
    required LatLng dropoff,
    String vehicleType = 'car',
    int seatsNeeded = 1,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rides = await _repo.findMatchingRides(
        pickupLat: pickup.latitude,
        pickupLng: pickup.longitude,
        dropoffLat: dropoff.latitude,
        dropoffLng: dropoff.longitude,
        vehicleType: vehicleType,
        seatsNeeded: seatsNeeded,
      );
      state = state.copyWith(rides: rides, isLoading: false);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: AppConstants.errorGeneric);
    }
  }

  void selectRide(RideModel ride) {
    state = state.copyWith(selectedRide: ride);
  }

  void clearSelected() {
    state = RideResultsState(rides: state.rides);
  }

  void reset() {
    state = const RideResultsState();
  }
}

final rideResultsProvider =
    StateNotifierProvider<RideResultsNotifier, RideResultsState>((ref) {
  return RideResultsNotifier(ref.read(rideRepositoryProvider));
});

// ─── Active Ride (Driver) ─────────────────────────────────────────────────────
class ActiveRideState {
  final RideModel? ride;
  final List<BookingModel> bookings;
  final bool isTracking;
  final bool canStart;
  final String? otpInput;
  final bool isLoading;

  const ActiveRideState({
    this.ride,
    this.bookings = const [],
    this.isTracking = false,
    this.canStart = false,
    this.otpInput,
    this.isLoading = false,
  });

  ActiveRideState copyWith({
    RideModel? ride,
    List<BookingModel>? bookings,
    bool? isTracking,
    bool? canStart,
    String? otpInput,
    bool? isLoading,
  }) {
    return ActiveRideState(
      ride: ride ?? this.ride,
      bookings: bookings ?? this.bookings,
      isTracking: isTracking ?? this.isTracking,
      canStart: canStart ?? this.canStart,
      otpInput: otpInput ?? this.otpInput,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ActiveRideNotifier extends StateNotifier<ActiveRideState> {
  final RideRepositoryImpl _repo;
  final SupabaseDataSource _supabase;
  final MapsService _maps;
  StreamSubscription<Position>? _locationSub;
  Timer? _heartbeatTimer;

  ActiveRideNotifier({
    required RideRepositoryImpl repo,
    required SupabaseDataSource supabase,
    required MapsService maps,
  })  : _repo = repo,
        _supabase = supabase,
        _maps = maps,
        super(const ActiveRideState());

  Future<void> loadRide(String rideId) async {
    state = state.copyWith(isLoading: true);
    final ride = await _supabase.getRide(rideId);
    final bookings = await _repo.getRideBookings(rideId);
    state = state.copyWith(ride: ride, bookings: bookings, isLoading: false);
  }

  void startLocationTracking(String driverId) {
    state = state.copyWith(isTracking: true);
    _locationSub = _maps.getLocationStream().listen((pos) async {
      await _supabase.upsertLiveLocation(
        driverId: driverId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        bearing: pos.heading,
        speed: pos.speed,
      );
      _checkCanStart(LatLng(pos.latitude, pos.longitude));
    });
  }

  void _checkCanStart(LatLng driverPos) {
    final acceptedBookings =
        state.bookings.where((b) => b.isAccepted).toList();
    if (acceptedBookings.isEmpty) {
      state = state.copyWith(canStart: true);
      return;
    }
    for (final b in acceptedBookings) {
      final pickup = LatLng(b.pickupLat, b.pickupLng);
      final dist = _maps.calculateDistance(driverPos, pickup);
      if (dist > AppConstants.matchRadiusMeters) {
        state = state.copyWith(canStart: false);
        return;
      }
    }
    state = state.copyWith(canStart: true);
  }

  Future<bool> verifyOtp(String bookingId, String otp) async {
    return await _repo.verifyOtp(bookingId: bookingId, otp: otp);
  }

  Future<void> startRide() async {
    if (state.ride == null) return;
    state = state.copyWith(isLoading: true);
    await _repo.startRide(state.ride!.id);
    state = state.copyWith(isLoading: false);
    await loadRide(state.ride!.id);
  }

  Future<void> completeRide() async {
    if (state.ride == null) return;
    state = state.copyWith(isLoading: true);
    await _repo.completeRide(state.ride!.id);
    _stopTracking();
    state = state.copyWith(isLoading: false, isTracking: false);
  }

  void _stopTracking() {
    _locationSub?.cancel();
    _heartbeatTimer?.cancel();
    final driverId = _supabase.currentUserId;
    if (driverId != null) _supabase.deleteLiveLocation(driverId);
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }
}

final activeRideProvider =
    StateNotifierProvider<ActiveRideNotifier, ActiveRideState>((ref) {
  return ActiveRideNotifier(
    repo: ref.read(rideRepositoryProvider),
    supabase: ref.read(supabaseDataSourceProvider),
    maps: ref.read(mapsServiceProvider),
  );
});

// ─── Offer Ride Flow ──────────────────────────────────────────────────────────
class OfferRideState {
  final List<RouteOption> routeOptions;
  final RouteOption? selectedRoute;
  final int seats;
  final String vehicleType; // 'car' or 'bike'
  final DateTime departureTime;
  final double? pricePerSeat;
  final bool isLoading;
  final String? error;
  final RideModel? createdRide;
  final List<Map<String, dynamic>> passengersOnRoute;

  OfferRideState({
    this.routeOptions = const [],
    this.selectedRoute,
    this.seats = 2,
    this.vehicleType = 'car',
    DateTime? departureTime,
    this.pricePerSeat,
    this.isLoading = false,
    this.error,
    this.createdRide,
    this.passengersOnRoute = const [],
  }) : departureTime = departureTime ?? DateTime.now().add(
          const Duration(minutes: 15));

  OfferRideState copyWith({
    List<RouteOption>? routeOptions,
    RouteOption? selectedRoute,
    int? seats,
    String? vehicleType,
    DateTime? departureTime,
    double? pricePerSeat,
    bool? isLoading,
    String? error,
    RideModel? createdRide,
    List<Map<String, dynamic>>? passengersOnRoute,
  }) {
    return OfferRideState(
      routeOptions: routeOptions ?? this.routeOptions,
      selectedRoute: selectedRoute ?? this.selectedRoute,
      seats: seats ?? this.seats,
      vehicleType: vehicleType ?? this.vehicleType,
      departureTime: departureTime ?? this.departureTime,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      createdRide: createdRide ?? this.createdRide,
      passengersOnRoute: passengersOnRoute ?? this.passengersOnRoute,
    );
  }
}

class OfferRideNotifier extends StateNotifier<OfferRideState> {
  final RideRepositoryImpl _repo;
  final MapsService _maps;
  final SupabaseDataSource _supabase;

  OfferRideNotifier({
    required RideRepositoryImpl repo,
    required MapsService maps,
    required SupabaseDataSource supabase,
  })  : _repo = repo,
        _maps = maps,
        _supabase = supabase,
        super(OfferRideState());

  Future<void> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final routes = await _maps.getRouteOptions(
        origin: origin,
        destination: destination,
        alternatives: 3,
      );
      state = state.copyWith(
        routeOptions: routes,
        selectedRoute: routes.isNotEmpty ? routes.first : null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppConstants.errorGeneric);
    }
  }

  void selectRoute(RouteOption route) {
    state = state.copyWith(selectedRoute: route);
  }

  void setSeats(int seats) => state = state.copyWith(seats: seats);
  void setVehicleType(String type) => state = state.copyWith(vehicleType: type);
  void setDepartureTime(DateTime time) =>
      state = state.copyWith(departureTime: time);
  void setPrice(double? price) => state = state.copyWith(pricePerSeat: price);

  Future<void> offerRide({
    required String driverId,
    required String originAddress,
    required String destinationAddress,
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (state.selectedRoute == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final ride = await _repo.createRide(
        driverId: driverId,
        originAddress: originAddress,
        destinationAddress: destinationAddress,
        originLat: origin.latitude,
        originLng: origin.longitude,
        destinationLat: destination.latitude,
        destinationLng: destination.longitude,
        routePolyline: state.selectedRoute!.encodedPolyline,
        availableSeats: state.vehicleType == 'bike' ? 1 : state.seats,
        departureTime: state.departureTime,
        pricePerSeat: state.pricePerSeat,
        vehicleType: state.vehicleType,
      );

      final passengers = await _supabase.getPassengersOnRoute(
        rideId: ride.id,
      );

      state = state.copyWith(
        createdRide: ride,
        passengersOnRoute: passengers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: e.toString());
    }
  }

  void reset() => state = OfferRideState();
}

final offerRideProvider =
    StateNotifierProvider<OfferRideNotifier, OfferRideState>((ref) {
  return OfferRideNotifier(
    repo: ref.read(rideRepositoryProvider),
    maps: ref.read(mapsServiceProvider),
    supabase: ref.read(supabaseDataSourceProvider),
  );
});

// ─── Passenger Booking State ──────────────────────────────────────────────────
class PassengerBookingState {
  final BookingModel? activeBooking;
  final bool isRequesting;
  final String? error;

  const PassengerBookingState({
    this.activeBooking,
    this.isRequesting = false,
    this.error,
  });

  PassengerBookingState copyWith({
    BookingModel? activeBooking,
    bool? isRequesting,
    String? error,
  }) {
    return PassengerBookingState(
      activeBooking: activeBooking ?? this.activeBooking,
      isRequesting: isRequesting ?? this.isRequesting,
      error: error,
    );
  }
}

class PassengerBookingNotifier extends StateNotifier<PassengerBookingState> {
  final RideRepositoryImpl _repo;
  final SupabaseDataSource _supabase;

  PassengerBookingNotifier({
    required RideRepositoryImpl repo,
    required SupabaseDataSource supabase,
  })  : _repo = repo,
        _supabase = supabase,
        super(const PassengerBookingState());

  Future<void> requestSeat({
    required RideModel ride,
    required String passengerId,
    required String pickupAddress,
    required String dropoffAddress,
    required LatLng pickupLatLng,
    required LatLng dropoffLatLng,
    int seatsRequested = 1,
    String vehicleType = 'car',
  }) async {
    state = state.copyWith(isRequesting: true, error: null);
    try {
      final booking = await _supabase.createBooking(
        rideId: ride.id,
        passengerId: passengerId,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        pickupLat: pickupLatLng.latitude,
        pickupLng: pickupLatLng.longitude,
        dropoffLat: dropoffLatLng.latitude,
        dropoffLng: dropoffLatLng.longitude,
        seatsRequested: seatsRequested,
        vehicleType: vehicleType,
      );
      state = state.copyWith(activeBooking: booking, isRequesting: false);
      _subscribeToBookingUpdates(passengerId);
    } catch (e) {
      state = state.copyWith(
          isRequesting: false, error: AppConstants.errorGeneric);
    }
  }

  Future<bool> cancelBooking() async {
    final bookingId = state.activeBooking?.id;
    if (bookingId == null) return false;
    final result = await _supabase.cancelBooking(bookingId);
    if (result) reset();
    return result;
  }

  void _subscribeToBookingUpdates(String passengerId) {
    _supabase.subscribeToPassengerBooking(
      passengerId: passengerId,
      onUpdate: (booking) {
        state = state.copyWith(activeBooking: booking);
      },
    );
  }

  void reset() => state = const PassengerBookingState();
}

final passengerBookingProvider =
    StateNotifierProvider<PassengerBookingNotifier, PassengerBookingState>((ref) {
  return PassengerBookingNotifier(
    repo: ref.read(rideRepositoryProvider),
    supabase: ref.read(supabaseDataSourceProvider),
  );
});

// ─── Driver Live Markers (for passenger map) ──────────────────────────────────
class DriverMarkersNotifier extends StateNotifier<Map<String, LatLng>> {
  final SupabaseDataSource _supabase;
  final List<dynamic> _channels = [];

  DriverMarkersNotifier(this._supabase) : super({});

  void trackDriver(String driverId) {
    final channel = _supabase.subscribeToDriverLocation(
      driverId: driverId,
      onUpdate: (loc) {
        state = {
          ...state,
          driverId: LatLng(loc.latitude, loc.longitude),
        };
      },
    );
    _channels.add(channel);
  }

  void stopTracking() {
    for (final ch in _channels) {
      _supabase.removeChannel(ch);
    }
    _channels.clear();
    state = {};
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

final driverMarkersProvider =
    StateNotifierProvider<DriverMarkersNotifier, Map<String, LatLng>>((ref) {
  return DriverMarkersNotifier(ref.read(supabaseDataSourceProvider));
});