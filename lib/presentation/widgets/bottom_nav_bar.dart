// lib/presentation/widgets/bottom_nav_bar.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

class SathChaloBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SathChaloBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          _navItem(0, Icons.search_rounded, 'Find'),
          _navItem(1, Icons.directions_car_rounded, 'Offer'),
          _navItem(2, Icons.history_rounded, 'History'),
          _navItem(3, Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive
                  ? AppTheme.accentGreen
                  : Colors.white.withOpacity(0.3),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? AppTheme.accentGreen
                    : Colors.white.withOpacity(0.3),
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
