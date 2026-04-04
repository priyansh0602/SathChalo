import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../providers/app_providers.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _vehicleNumberCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleColorCtrl = TextEditingController();
  bool _editingVehicle = false;

  @override
  void dispose() {
    _vehicleNumberCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleColorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider);
    if (profile == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('My Profile',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            child: Text('Logout',
                style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      profile.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile.fullName,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.phone,
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatChip(
                          label: 'Rides',
                          value: profile.totalRides.toString()),
                      const SizedBox(width: 12),
                      _StatChip(
                          label: 'Rating',
                          value: profile.rating.toStringAsFixed(1),
                          icon: Icons.star_rounded,
                          iconColor: Colors.amber),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Driver Mode Toggle ───────────────────────────────────────────
            _SectionCard(
              child: Row(
                children: [
                  Icon(Icons.drive_eta_rounded,
                      color: AppTheme.textPrimary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Driver Mode',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.textPrimary)),
                        Text('Offer rides to passengers',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: profile.isDriver,
                    activeColor: AppTheme.accentGreen,
                    onChanged: (val) async {
                      await ref
                          .read(authProvider.notifier)
                          .updateDriverMode(val);
                    },
                  ),
                ],
              ),
            ),

            // ─── Vehicle Info (if driver) ──────────────────────────────────
            if (profile.isDriver) ...[
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Vehicle Details',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                        TextButton(
                          onPressed: () =>
                              setState(() => _editingVehicle = !_editingVehicle),
                          child: Text(
                            _editingVehicle ? 'Cancel' : 'Edit',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.accentGreen,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_editingVehicle) ...[
                      _TextField(
                          ctrl: _vehicleNumberCtrl,
                          hint: 'DL 01 AB 1234',
                          label: 'Number Plate'),
                      const SizedBox(height: 10),
                      _TextField(
                          ctrl: _vehicleModelCtrl,
                          hint: 'e.g. Swift Dzire',
                          label: 'Car Model'),
                      const SizedBox(height: 10),
                      _TextField(
                          ctrl: _vehicleColorCtrl,
                          hint: 'e.g. White',
                          label: 'Color'),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await ref
                                .read(authProvider.notifier)
                                .updateVehicleInfo(
                                  vehicleNumber: _vehicleNumberCtrl.text.trim(),
                                  vehicleModel: _vehicleModelCtrl.text.trim(),
                                  vehicleColor: _vehicleColorCtrl.text.trim(),
                                );
                            setState(() => _editingVehicle = false);
                          },
                          child: const Text('Save Vehicle'),
                        ),
                      ),
                    ] else if (profile.hasVehicle) ...[
                      _InfoRow(label: 'Plate', value: profile.vehicleNumber!),
                      const SizedBox(height: 6),
                      _InfoRow(label: 'Model', value: profile.vehicleModel!),
                      const SizedBox(height: 6),
                      _InfoRow(label: 'Color', value: profile.vehicleColor!),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Add your vehicle details to offer rides.',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ─── Menu Items ────────────────────────────────────────────────
            _SectionCard(
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.history_rounded,
                    label: 'Ride History',
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  _MenuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'About SathChalo',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  const _StatChip({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlack,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.textPrimary)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final String label;

  const _TextField({
    required this.ctrl,
    required this.hint,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: AppTheme.accentGreen, width: 2),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;

  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}