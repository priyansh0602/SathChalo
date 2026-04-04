// lib/presentation/widgets/driver_card_horizontal.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import '../../data/models/profile_model.dart';

/// Uber-style horizontal driver card shown in the DraggableScrollableSheet.
/// Shows: Driver avatar, name, rating, vehicle, ETA, price, and a Request button.
class DriverCardHorizontal extends StatelessWidget {
  final RideModel ride;
  final String estimatedPickupTime;
  final String estimatedDistance;
  final VoidCallback onRequestSeat;
  final bool isRequesting;

  const DriverCardHorizontal({
    super.key,
    required this.ride,
    this.estimatedPickupTime = '—',
    this.estimatedDistance = '—',
    required this.onRequestSeat,
    this.isRequesting = false,
  });

  @override
  Widget build(BuildContext context) {
    final driver = ride.driver;
    final hasSeats = ride.hasSeats;

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                // ── Driver Info Row ──────────────────────────────
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        driver?.initials ?? 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver?.fullName ?? 'Driver',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                driver?.rating.toStringAsFixed(1) ?? '5.0',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '• ${driver?.vehicleModel ?? 'Car'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Stats Row ────────────────────────────────────
                Row(
                  children: [
                    _StatBlock(
                      icon: Icons.access_time_rounded,
                      value: estimatedPickupTime,
                      label: 'Pickup ETA',
                    ),
                    const SizedBox(width: 8),
                    _StatBlock(
                      icon: Icons.airline_seat_recline_normal_rounded,
                      value: '${ride.availableSeats}',
                      label: 'Seats left',
                    ),
                    const SizedBox(width: 8),
                    _StatBlock(
                      icon: Icons.payments_outlined,
                      value: ride.pricePerSeat != null
                          ? '₹${ride.pricePerSeat!.toStringAsFixed(0)}'
                          : 'Free',
                      label: 'per seat',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Route info ───────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.accentGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 1.5,
                            height: 18,
                            color: AppTheme.divider,
                          ),
                          const Icon(Icons.location_on,
                              size: 12, color: AppTheme.primary),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.originAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ride.destinationAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Departure time ───────────────────────────────
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Departs ${ride.departureTimeFormatted}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.near_me_rounded,
                              size: 10, color: AppTheme.accentGreen),
                          const SizedBox(width: 3),
                          Text(
                            '400m match',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Request Seat Button ─────────────────────────────
          GestureDetector(
            onTap: hasSeats && !isRequesting ? onRequestSeat : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: hasSeats ? AppTheme.primary : AppTheme.divider,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20)),
              ),
              alignment: Alignment.center,
              child: isRequesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasSeats
                              ? Icons.person_add_rounded
                              : Icons.block_rounded,
                          size: 16,
                          color: hasSeats
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasSeats ? 'Request Seat' : 'Full',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: hasSeats
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBlock({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
