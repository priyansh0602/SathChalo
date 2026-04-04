import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/map_models.dart';
import '../../providers/driver_provider.dart';
import '../../providers/app_providers.dart';
import '../driver/searching_riders_screen.dart';

class OfferRideScreen extends ConsumerStatefulWidget {
  const OfferRideScreen({super.key});

  @override
  ConsumerState<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends ConsumerState<OfferRideScreen> {
  GoogleMapController? _mapCtrl;

  // Step: 0=origin, 1=destination, 2=route, 3=details, 4=confirm
  int _step = 0;

  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _isSearchingOrigin = true;
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-fill origin with current location
      final search = ref.read(searchProvider);
      if (search.pickupAddress.isNotEmpty) {
        _originCtrl.text = search.pickupAddress;
      }
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String value, bool isOrigin) async {
    setState(() {
      _isSearchingOrigin = isOrigin;
      _isLoadingSuggestions = true;
    });
    final bias = ref.read(currentLatLngProvider);
    final maps = ref.read(mapsServiceProvider);
    final suggestions =
        await maps.getPlaceSuggestions(input: value, biasLocation: bias);
    setState(() {
      _suggestions = suggestions;
      _isLoadingSuggestions = false;
    });
  }

  Future<void> _onInputSubmitted() async {
    if (_suggestions.isNotEmpty) {
      await _selectSuggestion(_suggestions.first);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion s) async {
    final maps = ref.read(mapsServiceProvider);
    final latLng = await maps.getPlaceLatLng(s.placeId);
    setState(() => _suggestions = []);

    if (_isSearchingOrigin) {
      _originCtrl.text = s.fullText;
      ref.read(searchProvider.notifier).state = ref
          .read(searchProvider)
          .copyWith(pickupAddress: s.fullText, pickupLatLng: latLng);
    } else {
      _destinationCtrl.text = s.fullText;
      ref.read(searchProvider.notifier).state = ref
          .read(searchProvider)
          .copyWith(dropoffAddress: s.fullText, dropoffLatLng: latLng);
    }

    final search = ref.read(searchProvider);
    if (search.pickupLatLng != null && search.dropoffLatLng != null) {
      await _fetchRoutes();
    }
  }

  Future<void> _fetchRoutes() async {
    final search = ref.read(searchProvider);
    if (search.pickupLatLng == null || search.dropoffLatLng == null) return;

    setState(() => _step = 2);

    await ref.read(offerRideProvider.notifier).fetchRoutes(
          origin: search.pickupLatLng!,
          destination: search.dropoffLatLng!,
        );

    final offerState = ref.read(offerRideProvider);
    if (offerState.selectedRoute != null && _mapCtrl != null) {
      final maps = ref.read(mapsServiceProvider);
      final points =
          maps.decodePolyline(offerState.selectedRoute!.encodedPolyline);
      if (points.isNotEmpty) {
        final bounds = maps.boundsFromLatLngList(points);
        _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      }
    }
  }

  Future<void> _offerRide() async {
    var profile = ref.read(authProvider);
    if (profile == null) {
      // Auto-mock login for demo if skipped
      await ref.read(authProvider.notifier).mockLogin(
            name: 'Demo Driver',
            phone: '+919999999999',
          );
      profile = ref.read(authProvider);
      if (profile == null) return;
    }

    final search = ref.read(searchProvider);
    if (!search.isComplete) return;

    setState(() => _isLoadingSuggestions = true);

    await ref.read(offerRideProvider.notifier).offerRide(
          driverId: profile.id,
          originAddress: search.pickupAddress,
          destinationAddress: search.dropoffAddress,
          origin: search.pickupLatLng!,
          destination: search.dropoffLatLng!,
        );

    setState(() => _isLoadingSuggestions = false);

    final offerState = ref.read(offerRideProvider);
    if (offerState.createdRide != null) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SearchingRidersScreen(
            ride: offerState.createdRide!,
            initialPassengers: offerState.passengersOnRoute,
          ),
        ),
      );
    } else if (offerState.error != null) {
      _showSnack(offerState.error!);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final offerState = ref.watch(offerRideProvider);
    final search = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _stepTitle(),
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppTheme.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // Step progress
          _StepIndicator(currentStep: _step, totalSteps: 4),

          Expanded(
            child: _step <= 1
                ? _buildLocationInputStep(search)
                : _step == 2
                    ? _buildRouteSelectionStep(offerState, search)
                    : _buildDetailsStep(offerState),
          ),
        ],
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0:
      case 1:
        return 'Set Route';
      case 2:
        return 'Choose Route';
      case 3:
        return 'Ride Details';
      default:
        return 'Offer Ride';
    }
  }

  Widget _buildLocationInputStep(SearchState search) {
    return Column(
      children: [
        // Input fields
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 14),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                          width: 2, height: 32, color: Colors.grey.shade300),
                      const Icon(Icons.location_on,
                          color: AppTheme.primary, size: 16),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _originCtrl,
                          onChanged: (v) => _onSearchChanged(v, true),
                          onTap: () =>
                              setState(() => _isSearchingOrigin = true),
                          onSubmitted: (_) => _onInputSubmitted(),
                          decoration: const InputDecoration(
                            hintText: 'From where?',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        Container(height: 1, color: AppTheme.divider),
                        TextField(
                          controller: _destinationCtrl,
                          onChanged: (v) => _onSearchChanged(v, false),
                          onTap: () =>
                              setState(() => _isSearchingOrigin = false),
                          onSubmitted: (_) => _onInputSubmitted(),
                          decoration: const InputDecoration(
                            hintText: 'Where to?',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Suggestions
        Expanded(
          child: _isLoadingSuggestions
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary))
              : _suggestions.isNotEmpty
                  ? ListView.separated(
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 52),
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on_outlined,
                                size: 18,
                                color: AppTheme.textSecondary),
                          ),
                          title: Text(s.mainText,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(s.secondaryText,
                              style: const TextStyle(fontSize: 12)),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    )
                  : _buildRouteTips(),
        ),

        // Proceed button (if both set)
        if (search.isComplete)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _fetchRoutes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('See Route Options',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRouteTips() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tips for drivers',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ...[
            '🎯 Passengers within 400m of your route can request a seat',
            '💰 Set a fair price — typically ₹2–5 per km',
            '⭐ Maintain a good rating for more ride requests',
            '🔒 Always verify the OTP before starting the ride',
          ].map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(tip,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.4)),
              )),
        ],
      ),
    );
  }

  Widget _buildRouteSelectionStep(
      OfferRideState offerState, SearchState search) {
    return Column(
      children: [
        // Map
        SizedBox(
          height: 220,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: search.pickupLatLng ??
                  LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
              zoom: 12,
            ),
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (ctrl) {
              _mapCtrl = ctrl;
              ctrl.setMapStyle(AppTheme.mapStyle);
            },
            polylines: offerState.selectedRoute != null
                ? {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      color: AppTheme.primary,
                      width: 5,
                      points: ref
                          .read(mapsServiceProvider)
                          .decodePolyline(
                              offerState.selectedRoute!.encodedPolyline),
                    ),
                  }
                : {},
            markers: {
              if (search.pickupLatLng != null)
                Marker(
                  markerId: const MarkerId('origin'),
                  position: search.pickupLatLng!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                ),
              if (search.dropoffLatLng != null)
                Marker(
                  markerId: const MarkerId('dest'),
                  position: search.dropoffLatLng!,
                ),
            },
          ),
        ),

        // Route options
        Expanded(
          child: offerState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppTheme.primary))
              : offerState.routeOptions.isEmpty
                  ? const Center(child: Text('No routes found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: offerState.routeOptions.length,
                      itemBuilder: (_, i) {
                        final route = offerState.routeOptions[i];
                        final isSelected =
                            offerState.selectedRoute == route;
                        return _RouteOptionCard(
                          route: route,
                          isSelected: isSelected,
                          index: i,
                          onTap: () {
                            ref
                                .read(offerRideProvider.notifier)
                                .selectRoute(route);
                            // Update map polyline
                            final maps = ref.read(mapsServiceProvider);
                            final points =
                                maps.decodePolyline(route.encodedPolyline);
                            if (points.isNotEmpty && _mapCtrl != null) {
                              _mapCtrl!.animateCamera(
                                CameraUpdate.newLatLngBounds(
                                    maps.boundsFromLatLngList(points), 40),
                              );
                            }
                          },
                        );
                      },
                    ),
        ),

        // Next button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: offerState.selectedRoute != null
                  ? () => setState(() => _step = 3)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Choose this Route',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep(OfferRideState offerState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle type toggle
          _DetailSection(
            title: 'Vehicle Type',
            child: Row(
              children: [
                _VehicleTypeButton(
                  label: 'Car',
                  icon: Icons.directions_car_rounded,
                  isSelected: offerState.vehicleType == 'car',
                  onTap: () => ref
                      .read(offerRideProvider.notifier)
                      .setVehicleType('car'),
                ),
                const SizedBox(width: 12),
                _VehicleTypeButton(
                  label: 'Bike',
                  icon: Icons.two_wheeler_rounded,
                  isSelected: offerState.vehicleType == 'bike',
                  onTap: () {
                    ref
                        .read(offerRideProvider.notifier)
                        .setVehicleType('bike');
                    // Bike always has 1 seat
                    ref.read(offerRideProvider.notifier).setSeats(1);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Seats picker (only for Car)
          if (offerState.vehicleType == 'car')
          _DetailSection(
            title: 'Available Seats',
            child: Row(
              children: List.generate(
                4,
                (i) {
                  final seats = i + 1;
                  final isSelected = offerState.seats == seats;
                  return GestureDetector(
                    onTap: () => ref
                        .read(offerRideProvider.notifier)
                        .setSeats(seats),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? null
                            : Border.all(color: AppTheme.divider),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.airline_seat_recline_normal_rounded,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                          Text(
                            '$seats',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Departure time
          _DetailSection(
            title: 'Departure Time',
            child: GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(offerState.departureTime),
                );
                if (picked != null) {
                  final now = DateTime.now();
                  ref.read(offerRideProvider.notifier).setDepartureTime(
                        DateTime(
                            now.year, now.month, now.day, picked.hour, picked.minute),
                      );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      _formatTime(offerState.departureTime),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_rounded,
                        size: 14, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Price
          _DetailSection(
            title: 'Price per Seat (Optional)',
            child: TextField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                final price = double.tryParse(v);
                ref.read(offerRideProvider.notifier).setPrice(price);
              },
              decoration: InputDecoration(
                hintText: 'e.g. 50',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12, right: 8),
                  child: Text('₹',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Summary card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _SummaryRow(
                    label: 'Distance',
                    value: offerState.selectedRoute?.distance ?? '—'),
                _SummaryRow(
                    label: 'Duration',
                    value: offerState.selectedRoute?.duration ?? '—'),
                _SummaryRow(
                    label: 'Seats',
                    value: '${offerState.seats}'),
                _SummaryRow(
                    label: 'Price',
                    value: offerState.pricePerSeat != null
                        ? '₹${offerState.pricePerSeat!.toStringAsFixed(0)}/seat'
                        : 'Free'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Offer button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: offerState.isLoading ? null : _offerRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: offerState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Offer This Ride',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

// ─── Route Option Card ────────────────────────────────────────────────────────
class _RouteOptionCard extends StatelessWidget {
  final RouteOption route;
  final bool isSelected;
  final int index;
  final VoidCallback onTap;

  const _RouteOptionCard({
    required this.route,
    required this.isSelected,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labels = ['Fastest', 'Scenic', 'Alternative'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isSelected ? Colors.white : AppTheme.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        index < labels.length ? labels[index] : 'Route ${index + 1}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary),
                      ),
                      if (index == 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Recommended',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${route.duration} • ${route.distance}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  if (route.summary.isNotEmpty)
                    Text(
                      'Via ${route.summary}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Section ───────────────────────────────────────────────────────────
class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator(
      {required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: List.generate(
          totalSteps,
          (i) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
              height: 3,
              decoration: BoxDecoration(
                color: i <= currentStep
                    ? AppTheme.primary
                    : AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Vehicle Type Button ──────────────────────────────────────────────────────
class _VehicleTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
