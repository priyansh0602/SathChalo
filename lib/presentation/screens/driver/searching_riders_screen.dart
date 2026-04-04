// lib/presentation/screens/driver/searching_riders_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../data/models/profile_model.dart';
import '../../providers/driver_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/map_provider.dart';
import 'active_ride_screen.dart';

class SearchingRidersScreen extends ConsumerStatefulWidget {
  final RideModel ride;
  final List<Map<String, dynamic>> initialPassengers;

  const SearchingRidersScreen({
    super.key,
    required this.ride,
    this.initialPassengers = const [],
  });

  @override
  ConsumerState<SearchingRidersScreen> createState() =>
      _SearchingRidersScreenState();
}

class _SearchingRidersScreenState extends ConsumerState<SearchingRidersScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  int _dotCount = 1;
  Timer? _dotTimer;
  bool _synced = false;

  @override
  void initState() {
    super.initState();

    // Pulsing radar animation (2s loop)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Fade-in for content
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Animated dots "Searching..."
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount % 3) + 1);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRide());
  }

  Future<void> _syncRide() async {
    try {
      final profile = ref.read(authProvider);
      final rideWithDriver = widget.ride.copyWith(driver: profile);

      ref.read(driverProvider.notifier).syncRide(
            rideWithDriver.toEntity(),
            widget.initialPassengers,
          );

      // Also prepare the map provider for when dashboard opens
      ref.read(mapProvider.notifier).showActiveRide(rideWithDriver.toEntity());

      setState(() => _synced = true);
    } catch (e) {
      debugPrint('SearchingRidersScreen syncRide error: $e');
      setState(() => _synced = true); // Still allow UI to show
    }

    // Start fade-in
    if (mounted) _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  void _navigateToDashboard() {
    final driverState = ref.read(driverProvider);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveRideScreen(
          initialRide: driverState.activeRide ?? widget.ride.toEntity(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverProvider);
    final pendingCount =
        driverState.rideBookings.where((b) => b.isPending).length;
    final acceptedCount = driverState.rideBookings
        .where((b) => b.isAccepted || b.isActive)
        .length;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
            child: Column(
              children: [
                // ── Top Row ──
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const Spacer(),
                    _liveBadge(),
                  ],
                ),
                const SizedBox(height: 40),

                // ── Radar Animation ──
                _buildRadar(),
                const SizedBox(height: 28),

                // ── Searching text ──
                Text(
                  'Searching for riders${'.' * _dotCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Passengers within 400m of your route can join',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Route Summary Card ──
                _routeSummaryCard(),
                const SizedBox(height: 16),

                // ── Stats Row ──
                Row(
                  children: [
                    _statChip(
                      icon: Icons.people_alt_rounded,
                      label: 'Nearby',
                      value: '${driverState.passengersOnRoute.length}',
                      color: AppTheme.accentBlue,
                    ),
                    const SizedBox(width: 10),
                    _statChip(
                      icon: Icons.notifications_active_rounded,
                      label: 'Requests',
                      value: '$pendingCount',
                      color: AppTheme.warningYellow,
                    ),
                    const SizedBox(width: 10),
                    _statChip(
                      icon: Icons.check_circle_rounded,
                      label: 'Confirmed',
                      value: '$acceptedCount',
                      color: AppTheme.accentGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Pending Notification (if any) ──
                if (pendingCount > 0)
                  _pendingBanner(pendingCount),
                if (pendingCount > 0)
                  const SizedBox(height: 16),

                // ── View Dashboard Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _navigateToDashboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.dashboard_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          pendingCount > 0
                              ? 'View Requests ($pendingCount)'
                              : 'Open Ride Dashboard',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Radar Widget (inline, no separate class to avoid AnimatedBuilder issues)
  Widget _buildRadar() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final v = _pulseCtrl.value;
        final v2 = (v + 0.5) % 1.0;
        return SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ring 1
              Transform.scale(
                scale: 0.4 + v * 0.9,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentGreen
                          .withValues(alpha: 0.5 * (1 - v)),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              // Ring 2
              Transform.scale(
                scale: 0.4 + v2 * 0.9,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentGreen
                          .withValues(alpha: 0.35 * (1 - v2)),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Glow
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGreen.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentGreen.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
              // Center icon
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGreen,
                ),
                child: const Icon(Icons.wifi_tethering_rounded,
                    color: Colors.black, size: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Live badge
  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'RIDE LIVE',
            style: TextStyle(
              color: AppTheme.accentGreen,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Route Summary Card
  Widget _routeSummaryCard() {
    final ride = widget.ride;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Route dots column
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.accentGreen, width: 2.5),
                ),
              ),
              Container(
                width: 2,
                height: 28,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.errorRed, width: 2.5),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Addresses
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.originAddress,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                Text(
                  ride.destinationAddress,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Vehicle & price badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ride.vehicleType == 'bike'
                          ? Icons.two_wheeler_rounded
                          : Icons.directions_car_rounded,
                      color: AppTheme.accentGreen,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${ride.availableSeats} seat${ride.availableSeats != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ride.pricePerSeat != null && ride.pricePerSeat! > 0
                    ? '₹${ride.pricePerSeat!.toStringAsFixed(0)}/seat'
                    : 'Free ride',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stat Chip
  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pending Banner
  Widget _pendingBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: AppTheme.warningYellow, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count new ride request${count > 1 ? 's' : ''}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Open dashboard to accept or decline',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
