import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../presentation/providers/app_providers.dart';
import '../home/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _aadhaarCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _showOtp = false;
  bool _showIdentityPreview = false;
  
  String? _referenceId;
  Map<String, dynamic>? _fetchedIdentity;

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _aadhaarCtrl.dispose();
    _otpCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final number = _aadhaarCtrl.text.trim();
    if (number.length != 12) {
      _showSnack('Please enter a valid 12-digit Aadhaar number.');
      return;
    }
    setState(() => _isLoading = true);
    
    try {
      final kycService = ref.read(kycServiceProvider);
      _referenceId = await kycService.requestAadhaarOtp(number);
      setState(() {
        _isLoading = false;
        _showOtp = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Verification failed: $e');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      _showSnack('Enter the 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final kycService = ref.read(kycServiceProvider);
      final result = await kycService.verifyAadhaarOtp(
        referenceId: _referenceId!,
        otp: otp,
        aadhaarNumber: _aadhaarCtrl.text,
      );
      
      setState(() {
        _fetchedIdentity = result;
        _showIdentityPreview = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Invalid OTP. Please try again.');
    }
  }

  Future<void> _confirmLogin() async {
    if (_fetchedIdentity == null) return;
    
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).loginWithAadhaarDetails(
        name: _fetchedIdentity!['name'],
        phone: _fetchedIdentity!['phone'],
        gender: _fetchedIdentity!['gender'],
        dob: _fetchedIdentity!['dob'],
        lastFour: _fetchedIdentity!['last_four'],
      );
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _showSnack('Login failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // ─── Logo ─────────────────────────────────────────────────
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Login with\nAadhaar',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Secure identity verification for a safer journey',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 40),

                  if (_showIdentityPreview) ...[
                    // ─── Identity Summary Card ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person, color: AppTheme.accentBlue),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Identity Verified', 
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentBlue)),
                                    Text(_fetchedIdentity!['name'],
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.verified, color: AppTheme.accentBlue, size: 24),
                            ],
                          ),
                          const Divider(height: 32),
                          _IdentityRow(label: 'Gender', value: _fetchedIdentity!['gender']),
                          const SizedBox(height: 12),
                          _IdentityRow(label: 'Mobile', value: _fetchedIdentity!['phone']),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _confirmLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Confirm & Continue', 
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),

                  ] else if (!_showOtp) ...[
                    // ─── Aadhaar Field ──────────────────────────────────────
                    const _Label('Aadhaar Number'),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _aadhaarCtrl,
                      hint: '0000 0000 0000',
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      prefix: const Icon(Icons.badge_outlined,
                          size: 18, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white),
                              )
                            : const Text(
                                'Get OTP',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                      ),
                    ),
                  ] else ...[
                    // ─── OTP Section ────────────────────────────────────────
                    const Text('Verification Required', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Please enter the 6-digit code sent to your Aadhaar-linked mobile.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),

                    _InputField(
                      controller: _otpCtrl,
                      hint: 'xxxxxx',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      prefix: const Icon(Icons.lock_outline, size: 18),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Verify OTP',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _showOtp = false),
                        child: const Text('Change Aadhaar Number',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ─── Terms ───────────────────────────────────────────────
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withOpacity(0.7),
                          height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary));
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final Widget? prefix;
  final int? maxLength;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.prefix,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: maxLength != null
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        prefixIcon: prefix,
        filled: true,
        fillColor: AppTheme.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  final String label;
  final String value;
  const _IdentityRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ],
    );
  }
}