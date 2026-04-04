// lib/presentation/widgets/rating_dialog.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

/// "Rate your partner" popup shown after ride completion for both driver & passenger.
class RatingDialog extends StatefulWidget {
  final String partnerName;
  final String? partnerInitials;
  final bool isDriver; // true = rating the driver, false = rating the passenger
  final void Function(int rating, String? feedback) onSubmit;

  const RatingDialog({
    super.key,
    required this.partnerName,
    this.partnerInitials,
    this.isDriver = true,
    required this.onSubmit,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  final _feedbackCtrl = TextEditingController();
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  static const _labels = ['', 'Terrible', 'Bad', 'Okay', 'Good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Partner avatar
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.partnerInitials ??
                      widget.partnerName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Rate your ${widget.isDriver ? "driver" : "passenger"}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How was your ride with ${widget.partnerName}?',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = starIndex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        _rating >= starIndex
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: _rating >= starIndex ? 42 : 36,
                        color: _rating >= starIndex
                            ? Colors.amber
                            : AppTheme.divider,
                      ),
                    ),
                  );
                }),
              ),

              if (_rating > 0) ...[
                const SizedBox(height: 8),
                AnimatedOpacity(
                  opacity: _rating > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _labels[_rating],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _rating >= 4
                          ? AppTheme.accentGreen
                          : _rating >= 3
                              ? AppTheme.warningYellow
                              : AppTheme.errorRed,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Optional feedback
              TextField(
                controller: _feedbackCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Any feedback? (optional)',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppTheme.textHint),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _rating == 0
                      ? null
                      : () {
                          widget.onSubmit(
                            _rating,
                            _feedbackCtrl.text.trim().isEmpty
                                ? null
                                : _feedbackCtrl.text.trim(),
                          );
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    disabledBackgroundColor: AppTheme.divider,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Submit Rating',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Skip
              TextButton(
                onPressed: () {
                  widget.onSubmit(0, null);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
