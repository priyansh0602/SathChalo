// lib/presentation/widgets/route_option_card.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/map_models.dart';

class RouteOptionCard extends StatelessWidget {
  final RouteOption route;
  final bool isSelected;
  final VoidCallback onTap;

  const RouteOptionCard({
    super.key,
    required this.route,
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentGreen
                : Colors.white.withOpacity(0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Index circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentGreen
                    : const Color(0xFF2A2A2A),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${route.index + 1}',
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Route details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.summary.isEmpty
                        ? 'Route ${route.index + 1}'
                        : route.summary,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.straighten_rounded,
                          size: 12,
                          color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Text(
                        route.distance,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time_rounded,
                          size: 12,
                          color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Text(
                        route.duration,
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
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.accentGreen, size: 20),
          ],
        ),
      ),
    );
  }
}
