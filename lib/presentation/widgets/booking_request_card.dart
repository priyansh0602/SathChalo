// lib/presentation/widgets/booking_request_card.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import '../../domain/entities/ride.dart';

class BookingRequestCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const BookingRequestCard({
    super.key,
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (booking.passengerName ?? 'P').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                    if (booking.passengerRating != null)
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: AppTheme.warningYellow, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            booking.passengerRating!.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${booking.seatsRequested} seat',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.my_location_rounded,
                  color: AppTheme.accentGreen, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking.pickupAddress,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_rounded,
                  color: AppTheme.errorRed, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking.dropoffAddress,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Decline',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                  ),
                  child: const Text('Accept',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
