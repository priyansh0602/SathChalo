// lib/presentation/widgets/ride_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_theme.dart';
import '../../domain/entities/ride.dart';

class RideCard extends StatelessWidget {
  final Ride ride;
  final bool isSelected;
  final VoidCallback onTap;

  const RideCard({
    super.key,
    required this.ride,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentGreen.withOpacity(0.08)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentGreen
                : Colors.white.withOpacity(0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver info row
            Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      ride.driverName.isNotEmpty
                          ? ride.driverName[0].toUpperCase()
                          : 'D',
                      style: const TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 18,
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
                        ride.driverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: AppTheme.warningYellow, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            ride.driverRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ride.vehicleColor != null
                                ? '${ride.vehicleColor} ${ride.vehicleMake ?? ''}'
                                    .trim()
                                : 'Vehicle',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ride.isFree
                        ? AppTheme.accentGreen.withOpacity(0.15)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ride.isFree
                          ? AppTheme.accentGreen.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    ride.priceDisplay,
                    style: TextStyle(
                      color: ride.isFree
                          ? AppTheme.accentGreen
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF2D2D2D), height: 1),
            const SizedBox(height: 12),

            // Route info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _routePoint(
                        icon: Icons.my_location_rounded,
                        color: AppTheme.accentGreen,
                        label: ride.originAddress,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: Container(
                          width: 1,
                          height: 16,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      _routePoint(
                        icon: Icons.location_on_rounded,
                        color: AppTheme.errorRed,
                        label: ride.destinationAddress,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Departure time + seats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.4)),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('hh:mm a')
                              .format(ride.departureTime),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.4)),
                        const SizedBox(width: 4),
                        Text(
                          '${ride.availableSeats} seats',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (ride.distanceToPickupM != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.near_me_rounded,
                              size: 12,
                              color: AppTheme.accentBlue.withOpacity(0.8)),
                          const SizedBox(width: 4),
                          Text(
                            '${(ride.distanceToPickupM! / 1000).toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: AppTheme.accentBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // Vehicle plate
            if (ride.vehiclePlate != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ride.vehiclePlate!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _routePoint({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
