// lib/presentation/widgets/otp_display_widget.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

class OtpDisplayWidget extends StatelessWidget {
  final String otp;

  const OtpDisplayWidget({super.key, required this.otp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'YOUR OTP',
            style: TextStyle(
              color: AppTheme.accentGreen.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: otp.split('').map((digit) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 52,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentGreen.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Share this code with your driver',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
