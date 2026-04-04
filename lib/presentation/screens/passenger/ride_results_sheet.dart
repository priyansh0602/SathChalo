// lib/presentation/screens/passenger/ride_results_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../data/models/profile_model.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../widgets/radar_search_animation.dart';
import '../../widgets/driver_card_horizontal.dart';
import '../../widgets/rating_dialog.dart';
import '../home/home_screen.dart';

class RideResultsSheet extends ConsumerStatefulWidget {
  const RideResultsSheet({super.key});

  @override
  ConsumerState<RideResultsSheet> createState() => _RideResultsSheetState();
}

class _RideResultsSheetState extends ConsumerState<RideResultsSheet>
    with TickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  final _sheetCtrl = DraggableScrollableController();

  // ETA cache: rideId -> {duration, distance}
  final Map<String, Map<String, String>> _etaCache = {};

  // Lifecycle state
  _ScreenPhase _phase = _ScreenPhase.searching;
  RideModel? _selectedRide;
  BookingModel? _activeBooking;
  bool _isRequesting = false;

  // Realtime
  StreamSubscription? _bookingSub;
  StreamSubscription? _locationSub;

  // Driver live location for map
  LatLng? _driverLivePos;
  double _driverBearing = 0;

  // Proximity for "Complete Ride"
  bool _nearDestination = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSearch());
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 1: SEARCHING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startSearch() async {
    setState(() => _phase = _ScreenPhase.searching);

    final search = ref.read(searchProvider);
    if (!search.isComplete) return;

    await ref.read(rideResultsProvider.notifier).searchRides(
          pickup: search.pickupLatLng!,
          dropoff: search.dropoffLatLng!,
          vehicleType: search.vehicleType,
          seatsNeeded: search.seatsNeeded,
        );

    final results = ref.read(rideResultsProvider);

    if (results.rides.isEmpty) {
      // Subscribe to new rides in realtime — alert when a match appears
      _subscribeToNewRides();
      setState(() => _phase = _ScreenPhase.noResults);
    } else {
      // Fetch ETAs for all found rides
      _fetchETAs(results.rides);
      setState(() => _phase = _ScreenPhase.results);
      _fitMapToSearchBounds();
    }
  }

  void _subscribeToNewRides() {
    final db = ref.read(supabaseDataSourceProvider);
    final maps = ref.read(mapsServiceProvider);
    final search = ref.read(searchProvider);

    db.subscribeToNewRides(onNewRide: (newRide) {
      if (!mounted) return;
      // Check if this new ride passes near both pickup and dropoff
      if (newRide.routePolyline.isEmpty) return;
      final polyPoints = maps.decodePolyline(newRide.routePolyline);
      if (polyPoints.isEmpty) return;

      final pickupNear = maps.isPointNearPolyline(
        point: search.pickupLatLng!,
        polylinePoints: polyPoints,
      );
      final dropoffNear = maps.isPointNearPolyline(
        point: search.dropoffLatLng!,
        polylinePoints: polyPoints,
      );

      if (pickupNear && dropoffNear) {
        // New match found! Re-search
        _startSearch();
        _showSnack('🎉 A new matching ride just appeared!');
      }
    });
  }

  Future<void> _fetchETAs(List<RideModel> rides) async {
    final maps = ref.read(mapsServiceProvider);
    final search = ref.read(searchProvider);
    if (search.pickupLatLng == null) return;

    for (final ride in rides) {
      if (_etaCache.containsKey(ride.id)) continue;
      final eta = await maps.getEstimatedPickupTime(
        driverLocation: LatLng(ride.originLat, ride.originLng),
        passengerPickup: search.pickupLatLng!,
      );
      if (mounted) {
        setState(() => _etaCache[ride.id] = eta);
      }
    }
  }

  void _fitMapToSearchBounds() {
    final search = ref.read(searchProvider);
    final results = ref.read(rideResultsProvider);
    if (_mapCtrl == null) return;

    final points = <LatLng>[];
    if (search.pickupLatLng != null) points.add(search.pickupLatLng!);
    if (search.dropoffLatLng != null) points.add(search.dropoffLatLng!);
    for (final r in results.rides) {
      points.add(LatLng(r.originLat, r.originLng));
    }

    if (points.length >= 2) {
      final maps = ref.read(mapsServiceProvider);
      final bounds = maps.boundsFromLatLngList(points);
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 2: REQUEST SEAT (P2P Handshake)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _requestSeat(RideModel ride) async {
    var profile = ref.read(authProvider);
    if (profile == null) {
      await ref.read(authProvider.notifier).mockLogin(
            name: 'Demo Passenger',
            phone: '+918888888888',
          );
      profile = ref.read(authProvider);
    }
    
    final search = ref.read(searchProvider);
    if (profile == null || !search.isComplete) return;

    setState(() {
      _isRequesting = true;
      _selectedRide = ride;
    });

    try {
      await ref.read(passengerBookingProvider.notifier).requestSeat(
            ride: ride,
            passengerId: profile.id,
            pickupAddress: search.pickupAddress,
            dropoffAddress: search.dropoffAddress,
            pickupLatLng: search.pickupLatLng!,
            dropoffLatLng: search.dropoffLatLng!,
            seatsRequested: search.seatsNeeded,
            vehicleType: search.vehicleType,
          );

      final bookingState = ref.read(passengerBookingProvider);
      setState(() {
        _activeBooking = bookingState.activeBooking;
        _phase = _ScreenPhase.bookingPending;
        _isRequesting = false;
      });

      // Subscribe to booking updates (accept/reject)
      _subscribeToBookingUpdates(profile.id);
    } catch (e) {
      setState(() => _isRequesting = false);
      _showSnack('Failed to request seat');
    }
  }

  void _subscribeToBookingUpdates(String passengerId) {
    final db = ref.read(supabaseDataSourceProvider);
    db.subscribeToPassengerBooking(
      passengerId: passengerId,
      onUpdate: (booking) {
        if (!mounted) return;
        setState(() => _activeBooking = booking);

        if (booking.isAccepted) {
          setState(() => _phase = _ScreenPhase.bookingAccepted);
          // Start watching driver's live location
          _watchDriverLocation(_selectedRide!.driverId);
        } else if (booking.status == 'in_progress') {
          setState(() => _phase = _ScreenPhase.rideInProgress);
        } else if (booking.status == 'completed') {
          _showRatingDialog();
        } else if (booking.status == 'rejected') {
          setState(() => _phase = _ScreenPhase.results);
          _showSnack('Driver declined your request');
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 3: LIVE TRACKING
  // ═══════════════════════════════════════════════════════════════════════════

  void _watchDriverLocation(String driverId) {
    final db = ref.read(supabaseDataSourceProvider);
    final maps = ref.read(mapsServiceProvider);

    db.subscribeToDriverLocation(
      driverId: driverId,
      onUpdate: (loc) {
        if (!mounted) return;
        final newPos = LatLng(loc.latitude, loc.longitude);

        // Check proximity to destination (200m)
        final search = ref.read(searchProvider);
        if (search.dropoffLatLng != null) {
          final distToDest = maps.calculateDistance(newPos, search.dropoffLatLng!);
          if (distToDest <= 200 && !_nearDestination) {
            setState(() => _nearDestination = true);
          }
        }

        setState(() {
          _driverLivePos = newPos;
          _driverBearing = loc.bearing ?? 0;
        });

        // Animate camera to track driver
        _mapCtrl?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newPos, zoom: 16, bearing: _driverBearing),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 4: COMPLETION & RATING
  // ═══════════════════════════════════════════════════════════════════════════

  void _showRatingDialog() {
    final driver = _selectedRide?.driver;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        partnerName: driver?.fullName ?? 'Driver',
        partnerInitials: driver?.initials,
        isDriver: true,
        onSubmit: (rating, feedback) {
          // TODO: Save rating to Supabase
          _navigateHome();
        },
      ),
    );
  }

  void _navigateHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final results = ref.watch(rideResultsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ─── Google Map ──────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: search.pickupLatLng ??
                  const LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
              zoom: 13,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            markers: _buildMarkers(search, results),
            polylines: _buildPolylines(search),
            onMapCreated: (ctrl) {
              _mapCtrl = ctrl;
              ctrl.setMapStyle(AppTheme.mapStyle);
            },
          ),

          // ─── Back Button ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
                  const Spacer(),
                  if (_phase == _ScreenPhase.rideInProgress)
                    _liveBadge(),
                ],
              ),
            ),
          ),

          // ─── Bottom Content ─────────────────────────────────────────────
          _buildBottomContent(search, results),
        ],
      ),
    );
  }

  // ── Map Markers ──────────────────────────────────────────────────────────
  Set<Marker> _buildMarkers(SearchState search, RideResultsState results) {
    final markers = <Marker>{};

    // Pickup
    if (search.pickupLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: search.pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: search.pickupAddress),
      ));
    }

    // Dropoff
    if (search.dropoffLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: search.dropoffLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Dropoff', snippet: search.dropoffAddress),
      ));
    }

    // Driver markers (in results phase)
    if (_phase == _ScreenPhase.results) {
      for (final ride in results.rides) {
        markers.add(Marker(
          markerId: MarkerId('driver_${ride.id}'),
          position: LatLng(ride.originLat, ride.originLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: ride.driver?.fullName ?? 'Driver',
            snippet: '${ride.availableSeats} seats • ${ride.departureTimeFormatted}',
          ),
        ));
      }
    }

    // Live driver marker (in tracking phase)
    if (_driverLivePos != null &&
        (_phase == _ScreenPhase.bookingAccepted ||
            _phase == _ScreenPhase.rideInProgress)) {
      markers.add(Marker(
        markerId: const MarkerId('live_driver'),
        position: _driverLivePos!,
        rotation: _driverBearing,
        anchor: const Offset(0.5, 0.5),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(
          title: _selectedRide?.driver?.fullName ?? 'Driver',
          snippet: _phase == _ScreenPhase.rideInProgress
              ? 'On the way'
              : 'Coming to pick you up',
        ),
      ));
    }

    return markers;
  }

  // ── Polylines (pickup segment highlight) ─────────────────────────────────
  Set<Polyline> _buildPolylines(SearchState search) {
    final polylines = <Polyline>{};

    // If we have a selected ride, show its route
    if (_selectedRide != null && _selectedRide!.routePolyline.isNotEmpty) {
      final maps = ref.read(mapsServiceProvider);
      final points = maps.decodePolyline(_selectedRide!.routePolyline);

      // Full route (grey)
      polylines.add(Polyline(
        polylineId: const PolylineId('full_route'),
        points: points,
        color: Colors.grey.shade400,
        width: 4,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));

      // Pickup segment highlight (if we have driver live pos and pickup)
      if (_driverLivePos != null && search.pickupLatLng != null) {
        final pickupSegment = _extractSegment(
          points,
          _driverLivePos!,
          search.pickupLatLng!,
        );
        if (pickupSegment.isNotEmpty) {
          polylines.add(Polyline(
            polylineId: const PolylineId('pickup_segment'),
            points: pickupSegment,
            color: AppTheme.primary,
            width: 6,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ));
        }
      }
    }

    return polylines;
  }

  /// Extract the sub-polyline between the two points nearest to `from` and `to`
  List<LatLng> _extractSegment(
      List<LatLng> polyline, LatLng from, LatLng to) {
    if (polyline.length < 2) return [];
    final maps = ref.read(mapsServiceProvider);

    int fromIdx = 0, toIdx = polyline.length - 1;
    double minFromDist = double.infinity, minToDist = double.infinity;

    for (int i = 0; i < polyline.length; i++) {
      final d1 = maps.calculateDistance(polyline[i], from);
      if (d1 < minFromDist) {
        minFromDist = d1;
        fromIdx = i;
      }
      final d2 = maps.calculateDistance(polyline[i], to);
      if (d2 < minToDist) {
        minToDist = d2;
        toIdx = i;
      }
    }

    if (fromIdx > toIdx) {
      final tmp = fromIdx;
      fromIdx = toIdx;
      toIdx = tmp;
    }

    return polyline.sublist(fromIdx, toIdx + 1);
  }

  // ── Bottom Content (phase-dependent) ─────────────────────────────────────
  Widget _buildBottomContent(SearchState search, RideResultsState results) {
    switch (_phase) {
      case _ScreenPhase.searching:
        return _buildSearchingSheet();
      case _ScreenPhase.noResults:
        return _buildNoResultsSheet();
      case _ScreenPhase.results:
        return _buildResultsSheet(results);
      case _ScreenPhase.bookingPending:
        return _buildBookingPendingSheet();
      case _ScreenPhase.bookingAccepted:
        return _buildBookingAcceptedSheet();
      case _ScreenPhase.rideInProgress:
        return _buildRideInProgressSheet();
    }
  }

  // ── SEARCHING ──────────────────────────────────────────────────────────
  Widget _buildSearchingSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppTheme.bottomSheetShadow,
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: RadarSearchAnimation(
          message: 'Scanning for rides...',
          submessage: 'Looking for drivers within 400m of your route',
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // ── NO RESULTS ──────────────────────────────────────────────────────────
  Widget _buildNoResultsSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppTheme.bottomSheetShadow,
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_car_outlined,
                  size: 32, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('No rides found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'We\'re listening for new drivers.\nYou\'ll be notified instantly when one appears.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 16),
            // Pulsing dot indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Listening for matches...',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentGreen,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: AppTheme.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startSearch,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Retry',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── RESULTS (Uber-style horizontal cards) ─────────────────────────────
  Widget _buildResultsSheet(RideResultsState results) {
    return DraggableScrollableSheet(
      controller: _sheetCtrl,
      initialChildSize: 0.48,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppTheme.bottomSheetShadow,
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.zero,
          children: [
            _handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${results.rides.length} ride${results.rides.length != 1 ? 's' : ''} found',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Swipe to compare drivers',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _startSearch,
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppTheme.textSecondary, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Horizontal scrolling driver cards
            SizedBox(
              height: 360,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: results.rides.length,
                itemBuilder: (_, i) {
                  final ride = results.rides[i];
                  final eta = _etaCache[ride.id];
                  return DriverCardHorizontal(
                    ride: ride,
                    estimatedPickupTime: eta?['duration'] ?? '—',
                    estimatedDistance: eta?['distance'] ?? '—',
                    onRequestSeat: () => _requestSeat(ride),
                    isRequesting: _isRequesting && _selectedRide?.id == ride.id,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── BOOKING PENDING ─────────────────────────────────────────────────────
  Widget _buildBookingPendingSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppTheme.bottomSheetShadow,
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  size: 32, color: AppTheme.warning),
            ),
            const SizedBox(height: 16),
            const Text('Request Sent!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Waiting for ${_selectedRide?.driver?.fullName ?? "driver"} to accept...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.divider,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => ref.read(passengerBookingProvider.notifier).cancelBooking(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: AppTheme.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel Request',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BOOKING ACCEPTED (show OTP) ─────────────────────────────────────────
  Widget _buildBookingAcceptedSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppTheme.bottomSheetShadow,
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 16),

            // Driver info row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _selectedRide?.driver?.initials ?? 'D',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedRide?.driver?.fullName ?? 'Driver',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      Text(
                        '${_selectedRide?.driver?.vehicleModel ?? 'Car'} • ${_selectedRide?.driver?.vehicleNumber ?? ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Accepted ✓',
                      style: TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            const Text('Your OTP',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1)),
            const SizedBox(height: 10),

            // OTP display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _activeBooking?.otp ?? '----',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Show this code to your driver when they arrive',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => ref.read(passengerBookingProvider.notifier).cancelBooking(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: AppTheme.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel Ride',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── RIDE IN PROGRESS ────────────────────────────────────────────────────
  Widget _buildRideInProgressSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppTheme.bottomSheetShadow,
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Ride in progress',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            // Driver info
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _selectedRide?.driver?.initials ?? 'D',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedRide?.driver?.fullName ?? 'Driver',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
                      ),
                      Text(
                        '${_selectedRide?.driver?.vehicleModel ?? 'Car'} • ${_selectedRide?.driver?.vehicleNumber ?? ''}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_nearDestination) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.flag_rounded, color: AppTheme.accentGreen, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Almost there! You\'re within 200m of your destination.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.accentGreen,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Small Helpers ───────────────────────────────────────────────────────
  Widget _handle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: AppTheme.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppTheme.cardShadow,
        ),
        child: Icon(icon, size: 20, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: AppTheme.errorRed),
          SizedBox(width: 6),
          Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

enum _ScreenPhase {
  searching,
  noResults,
  results,
  bookingPending,
  bookingAccepted,
  rideInProgress,
}