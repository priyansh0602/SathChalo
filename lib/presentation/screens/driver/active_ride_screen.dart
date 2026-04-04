// lib/presentation/screens/driver/active_ride_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/constants/app_theme.dart';
import '../../../domain/entities/ride.dart';
import '../../providers/driver_provider.dart';
import '../../providers/map_provider.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/booking_request_card.dart';
import '../home/home_screen.dart';

class ActiveRideScreen extends ConsumerStatefulWidget {
  final Ride? initialRide;
  const ActiveRideScreen({super.key, this.initialRide});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Timer? _locationTimer;
  bool _showOtpSheet = false;
  String? _otpBookingId;
  String _otpInput = '';
  bool _verifyingOtp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialRide != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ride = widget.initialRide!;
        ref.read(driverProvider.notifier).syncRide(ride);
        // Pre-populate map data so it's ready on first build
        ref.read(mapProvider.notifier).showActiveRide(ride);
      });
    }
  }

  void _startLocationTracking() {
    final driverState = ref.read(driverProvider);
    final ride = driverState.activeRide;
    if (ride != null) {
      ref.read(mapProvider.notifier).startLocationUpload(ride.id);
      // Sync map to show the route
      ref.read(mapProvider.notifier).showActiveRide(ride);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationTimer?.cancel();
    ref.read(mapProvider.notifier).stopLocationUpload();
    super.dispose();
  }

  Future<void> _verifyOtp(BuildContext context) async {
    if (_otpBookingId == null || _otpInput.length != 4) return;
    setState(() => _verifyingOtp = true);
    try {
      final result = await ref
          .read(driverProvider.notifier)
          .verifyOtp(_otpBookingId!, _otpInput);
      if (result['success'] == true) {
        setState(() => _showOtpSheet = false);
        ref.read(driverProvider.notifier).startRide();
        _showSuccessSnack(context, 'OTP verified! Ride started 🚗');
      } else {
        _showErrorSnack(context, result['message'] ?? 'Invalid OTP');
      }
    } catch (e) {
      _showErrorSnack(context, 'Verification failed');
    } finally {
      setState(() => _verifyingOtp = false);
    }
  }

  void _showSuccessSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showErrorSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.errorRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverProvider);
    final mapState = ref.watch(mapProvider);

    // Reactively update map when ride is available or changes
    ref.listen(driverProvider.select((s) => s.activeRide), (prev, next) {
      if (next != null) {
        Future.microtask(() {
          ref.read(mapProvider.notifier).showActiveRide(next);
          ref.read(mapProvider.notifier).startLocationUpload(next.id);
        });
      }
    });

    if (driverState.activeRide == null) {
      // If we have an initialRide, give it time to sync rather than showing blank
      if (widget.initialRide != null) {
        return _buildSyncingScreen();
      }
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark grey, but not black
      body: Stack(
        children: [
          // Map
          Positioned.fill(
            child: MapWidget(
              markers: mapState.markers,
              polylines: mapState.polylines,
              circles: mapState.circles,
              initialPosition: driverState.activeRide?.origin ??
                  mapState.currentLocation ??
                  const LatLng(28.6139, 77.2090),
              onMapCreated: (ctrl) {
                ref.read(mapProvider.notifier).setMapController(ctrl);
              },
            ),
          ),

          // Top bar — always visible
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _topChip(
                    icon: Icons.radio_button_checked,
                    label: 'LIVE',
                    color: AppTheme.errorRed,
                  ),
                  const Spacer(),
                  _topChip(
                    icon: Icons.directions_car_rounded,
                    label: driverState.activeRide?.vehicleInfo ??
                        'Your Vehicle',
                    color: AppTheme.accentGreen,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Panel — always visible
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(context, driverState),
          ),

          // OTP verification overlay
          if (_showOtpSheet)
            _buildOtpOverlay(context),
        ],
      ),
    );
  }

  Widget _buildMapLoadingOverlay() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SearchingIndicator(),
            const SizedBox(height: 24),
            Text(
              'Initializing Map...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Acquiring graphics surface...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, DriverState state) {
    final pending = state.rideBookings.where((b) => b.isPending).toList();
    final accepted = state.rideBookings.where((b) => b.isAccepted || b.isActive).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.isOnRide ? 'Ride in Progress' : 'Ride Published',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded, color: AppTheme.accentGreen, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${accepted.length}/${state.availableSeats}',
                      style: const TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Requests / Passengers list
          if (pending.isNotEmpty) ...[
            const Text(
              'New Requests',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180, // Fix height for list
              child: _buildRequestsList(context, state),
            ),
          ] else if (accepted.isNotEmpty) ...[
            const Text(
              'Passengers on board',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180, // Fix height for list
              child: _buildPassengersList(context, state),
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _SearchingIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Searching for people near your route...',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // End Ride button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _confirmEndRide(context),
              icon: const Icon(Icons.stop_circle_outlined, color: AppTheme.errorRed, size: 20),
              label: const Text('End Ride', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.errorRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildRequestsList(BuildContext context, DriverState state) {
    final pending = state.rideBookings.where((b) => b.isPending).toList();
    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SearchingIndicator(),
            const SizedBox(height: 16),
            Text(
              state.passengersOnRoute.isNotEmpty
                  ? 'Matched ${state.passengersOnRoute.length} potential passengers!'
                  : 'Searching for people near your route...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.passengersOnRoute.isNotEmpty
                  ? 'They will see your ride in their search results'
                  : 'Matching passengers within 400m corridor',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => BookingRequestCard(
        booking: pending[i],
        onAccept: () =>
            ref.read(driverProvider.notifier).acceptBooking(pending[i].id),
        onReject: () =>
            ref.read(driverProvider.notifier).rejectBooking(pending[i].id),
      ),
    );
  }

  Widget _buildPassengersList(BuildContext context, DriverState state) {
    final accepted = state.rideBookings
        .where((b) => b.isAccepted || b.isActive)
        .toList();
    if (accepted.isEmpty) {
      return Center(
        child: Text(
          'No passengers yet',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 13,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: accepted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final booking = accepted[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (booking.passengerName ?? 'P')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.accentGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.passengerName ?? 'Passenger',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      booking.pickupAddress,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // OTP verify button
              if (!booking.otpVerified)
                GestureDetector(
                  onTap: () => setState(() {
                    _showOtpSheet = true;
                    _otpBookingId = booking.id;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Verify OTP',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppTheme.successGreen, size: 12),
                      SizedBox(width: 4),
                      Text('Verified',
                          style: TextStyle(
                              color: AppTheme.successGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOtpOverlay(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showOtpSheet = false),
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping the card
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_open_rounded,
                        color: AppTheme.accentGreen, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter Passenger OTP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask passenger for their 4-digit code',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PinCodeTextField(
                    appContext: context,
                    length: 4,
                    obscureText: false,
                    animationType: AnimationType.fade,
                    keyboardType: TextInputType.number,
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(12),
                      fieldHeight: 56,
                      fieldWidth: 56,
                      activeFillColor: const Color(0xFF2A2A2A),
                      inactiveFillColor: const Color(0xFF1E1E1E),
                      selectedFillColor: const Color(0xFF2A2A2A),
                      activeColor: AppTheme.accentGreen,
                      inactiveColor: Colors.white.withOpacity(0.1),
                      selectedColor: AppTheme.accentGreen,
                    ),
                    enableActiveFill: true,
                    onCompleted: (v) => setState(() => _otpInput = v),
                    onChanged: (v) => setState(() => _otpInput = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _otpInput.length != 4 || _verifyingOtp
                          ? null
                          : () => _verifyOtp(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _verifyingOtp
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2),
                            )
                          : const Text('Verify & Start Ride',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmEndRide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End ride?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This will mark the ride as complete.',
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(driverProvider.notifier).endRide();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('End Ride',
                style: TextStyle(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated car icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: AppTheme.accentGreen,
                size: 36,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Preparing your ride...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accentGreen),
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading map and route data',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                color: AppTheme.accentGreen,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Publishing your ride...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.initialRide != null 
                  ? 'Ride ID: ${widget.initialRide!.id.substring(0, 8)}...' 
                  : 'Syncing with SathChalo...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Waiting for data synchronization...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchingIndicator extends StatefulWidget {
  const _SearchingIndicator();

  @override
  State<_SearchingIndicator> createState() => _SearchingIndicatorState();
}

class _SearchingIndicatorState extends State<_SearchingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40 * _controller.value,
              height: 40 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen.withOpacity(0.5 * (1 - _controller.value)),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen,
              ),
            ),
          ],
        );
      },
    );
  }
}
