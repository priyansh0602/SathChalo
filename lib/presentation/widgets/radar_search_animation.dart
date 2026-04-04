// lib/presentation/widgets/radar_search_animation.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

/// A premium radar/ripple scanning animation shown while searching for rides.
/// 3 concentric expanding rings with a pulsing center dot.
class RadarSearchAnimation extends StatefulWidget {
  final String message;
  final String? submessage;
  final VoidCallback? onCancel;
  final Color color;

  const RadarSearchAnimation({
    super.key,
    this.message = 'Scanning for rides nearby...',
    this.submessage,
    this.onCancel,
    this.color = const Color(0xFF000000),
  });

  @override
  State<RadarSearchAnimation> createState() => _RadarSearchAnimationState();
}

class _RadarSearchAnimationState extends State<RadarSearchAnimation>
    with TickerProviderStateMixin {
  late final List<AnimationController> _rippleCtrls;
  late final AnimationController _pulseCtrls;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // 3 staggered ripple rings
    _rippleCtrls = List.generate(3, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      );
      Future.delayed(Duration(milliseconds: i * 800), () {
        if (mounted) ctrl.repeat();
      });
      return ctrl;
    });

    // Center dot pulse
    _pulseCtrls = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrls, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    for (final c in _rippleCtrls) {
      c.dispose();
    }
    _pulseCtrls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Radar area
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple rings
              ..._rippleCtrls.map((ctrl) => AnimatedBuilder(
                    animation: ctrl,
                    builder: (_, __) {
                      final value = ctrl.value;
                      return Container(
                        width: 60 + (140 * value),
                        height: 60 + (140 * value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.color.withOpacity(
                                0.4 * (1.0 - value)),
                            width: 2.0 * (1.0 - value * 0.5),
                          ),
                        ),
                      );
                    },
                  )),

              // Center pulse dot
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Message
        Text(
          widget.message,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        if (widget.submessage != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.submessage!,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        if (widget.onCancel != null) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: widget.onCancel,
            child: const Text(
              'Cancel Search',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

