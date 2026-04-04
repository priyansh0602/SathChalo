import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../presentation/providers/app_providers.dart';
import '../driver/offer_ride_screen.dart';
import '../passenger/search_screen.dart';
import '../profile/user_profile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _mapCtrl;
  bool _hasCentered = false;
  bool _isWomenOnly = false;

  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
    zoom: AppConstants.defaultZoom,
  );

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final mapsService = ref.read(mapsServiceProvider);
    final hasPermission = await mapsService.requestLocationPermission();
    if (!hasPermission) return;

    // Force a rebuild so GoogleMap re-checks permissions and displays the native blue dot
    if (mounted) setState(() {});

    final position = await mapsService.getCurrentPosition();
    if (position == null) return;

    final latLng = LatLng(position.latitude, position.longitude);

    // Auto-fill pickup address
    ref.read(searchProvider.notifier).initPickupFromLocation(latLng);

    // Move camera
    if (_mapCtrl != null && !_hasCentered) {
      _hasCentered = true;
      _mapCtrl?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 15),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider);
    final locationState = ref.watch(locationProvider);
    final mapState = ref.watch(homeMapProvider);

    // Move camera when location updates initially
    ref.listen(locationProvider, (prev, next) {
      if (next != null && _mapCtrl != null && !_hasCentered) {
        _hasCentered = true;
        _mapCtrl!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(next.latitude, next.longitude),
              zoom: 15,
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ─── Google Map ─────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _defaultCamera,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            markers: mapState.markers,
            polylines: mapState.polylines,
            onMapCreated: (ctrl) {
              _mapCtrl = ctrl;
              ctrl.setMapStyle(AppTheme.mapStyle);
              if (locationState != null && !_hasCentered) {
                _hasCentered = true;
                ctrl.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                          locationState.latitude, locationState.longitude),
                      zoom: 15,
                    ),
                  ),
                );
              }
            },
          ),

          // ─── Top Bar ─────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      // Profile button
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const UserProfileScreen()),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.cardShadow,
                          ),
                          alignment: Alignment.center,
                          child: profile != null
                              ? Text(
                                  profile.initials,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary),
                                )
                              : const Icon(Icons.person_outline,
                                  size: 20, color: AppTheme.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Search bar (tap to open search screen)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SearchScreen()),
                          ),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    size: 18, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Where are you going?',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary
                                          .withOpacity(0.8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Bottom Action Buttons ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: AppTheme.bottomSheetShadow,
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Greeting
                  if (profile != null) ...[
                    Row(
                      children: [
                        Text(
                          'Good ${_greeting()}, ',
                          style: const TextStyle(
                              fontSize: 18,
                              color: AppTheme.textSecondary),
                        ),
                        Text(
                          profile.fullName.split(' ').first,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Where would you like to go?',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Women Only Toggle (UI Only) ────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.female_rounded,
                              color: AppTheme.accentGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Women Only Ride',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Travel exclusively with women',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isWomenOnly,
                          activeColor: AppTheme.accentGreen,
                          onChanged: (val) {
                            setState(() => _isWomenOnly = val);
                          },
                        ),
                      ],
                    ),
                  ),

                  // ─── Offer / Find Buttons ───────────────────────────────
                  Row(
                    children: [
                      // FIND A RIDE
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.search_rounded,
                          label: 'Find a Ride',
                          subtitle: 'Passenger',
                          color: AppTheme.primary,
                          textColor: Colors.white,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SearchScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // OFFER A RIDE
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.drive_eta_rounded,
                          label: 'Offer a Ride',
                          subtitle: 'Driver',
                          color: AppTheme.background,
                          textColor: AppTheme.textPrimary,
                          border: true,
                          onTap: () {
                            if (profile == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const OfferRideScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ─── Quick Destinations ─────────────────────────────────
                  const _QuickDestRow(),
                ],
              ),
            ),
          ),

          // ─── My Location FAB ──────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 260,
            child: GestureDetector(
              onTap: () {
                final pos = ref.read(locationProvider);
                if (pos != null) {
                  _mapCtrl?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                          target: LatLng(pos.latitude, pos.longitude),
                          zoom: 15),
                    ),
                  );
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: const Icon(Icons.my_location_rounded,
                    size: 20, color: AppTheme.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

// ─── Action Button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color textColor;
  final bool border;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.border = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: border
              ? Border.all(color: AppTheme.divider, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: border
                    ? Colors.white
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: border ? AppTheme.textPrimary : Colors.white,
                  size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: textColor.withOpacity(0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Dest Row ─────────────────────────────────────────────────────────
class _QuickDestRow extends StatelessWidget {
  const _QuickDestRow();

  static const _destinations = [
    _QuickDest(icon: Icons.home_outlined, label: 'Home'),
    _QuickDest(icon: Icons.work_outline_rounded, label: 'Work'),
    _QuickDest(icon: Icons.train_outlined, label: 'Metro'),
    _QuickDest(icon: Icons.add_rounded, label: 'Add'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _destinations
          .map((d) => _QuickDestChip(dest: d))
          .toList(),
    );
  }
}

class _QuickDest {
  final IconData icon;
  final String label;
  const _QuickDest({required this.icon, required this.label});
}

class _QuickDestChip extends StatelessWidget {
  final _QuickDest dest;
  const _QuickDestChip({required this.dest});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(dest.icon, size: 15, color: AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(dest.label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}