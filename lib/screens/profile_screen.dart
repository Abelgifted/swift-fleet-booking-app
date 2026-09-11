import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/premium_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/premium_bottom_sheet.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_input.dart';
import '../widgets/responsive.dart';

/// Member profile: gold-framed avatar, live stats and account actions.
class ProfileScreen extends StatefulWidget {
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;

  Future<void> _editProfile() async {
    final auth = context.read<AuthProvider>();
    final nameController =
        TextEditingController(text: auth.user?.customerName ?? '');
    final phoneController =
        TextEditingController(text: auth.user?.phone ?? '');
    final formKey = GlobalKey<FormState>();

    final save = await showPremiumBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SheetBody(
          title: 'Edit profile',
          subtitle: 'Keep your details current for smooth check-in.',
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumTextField(
                  controller: nameController,
                  label: 'Full name',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) => Validators.required(v, 'Name'),
                ),
                const SizedBox(height: 14),
                PremiumTextField(
                  controller: phoneController,
                  label: 'Phone number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 20),
                Consumer<AuthProvider>(
                  builder: (_, a, _) => PremiumButton(
                    label: 'Save changes',
                    loading: a.isLoading,
                    onPressed: a.isLoading
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ??
                                false)) {
                              return;
                            }
                            final ok = await a.updateProfile(
                              name: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                            );
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop(ok);
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(save == true
            ? 'Profile updated'
            : context.read<AuthProvider>().errorMessage ??
                'No changes saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log out?', style: Lux.headline(ctx, size: 20)),
        content: Text(
          'You will need to sign in again to book trips.',
          style: Lux.body(ctx, size: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Lux.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().logout();
    navigator.pushNamedAndRemoveUntil(AppConstants.routeLogin, (r) => false);
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what is coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: body,
    );
  }

  Widget _body() {
    final auth = context.watch<AuthProvider>();
    final booking = context.watch<BookingProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;
    final isPhone = Breakpoints.isPhone(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => auth.refreshProfile(),
      child: ContentShell(
        maxWidth: isPhone ? 720 : 860,
        padding: EdgeInsets.zero,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── Header ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              decoration: BoxDecoration(
                gradient: isDark ? Lux.inkGradient : Lux.metallic,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(Lux.rXl),
                ),
                boxShadow: Lux.soft,
              ),
              child: Column(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Lux.goldGradient,
                      border: Border.all(
                        color: Lux.ivory.withValues(alpha: 0.9),
                        width: 3,
                      ),
                      boxShadow: Lux.goldGlow,
                    ),
                    child: Center(
                      child: Text(
                        (user?.customerName.isNotEmpty ?? false)
                            ? user!.customerName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          color: Lux.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.customerName ?? 'Traveller',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      color: Lux.ivory,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Not signed in',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Lux.ivory.withValues(alpha: 0.7),
                    ),
                  ),
                  if (user?.phone.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      Formatters.maskPhone(user!.phone),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Lux.ivory.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 210,
                    child: PremiumButton(
                      label: 'Edit profile',
                      icon: Icons.edit_outlined,
                      onPressed: _editProfile,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats ───────────────────────────────────────
                  Row(
                    children: [
                      _Stat(
                        value: '${booking.history.length}',
                        label: 'Bookings',
                        icon: Icons.confirmation_number_outlined,
                      ),
                      const SizedBox(width: 12),
                      _Stat(
                        value: Formatters.currency(
                          booking.walletBalance > 0
                              ? booking.walletBalance
                              : (user?.balance ?? 0),
                          withDecimals: false,
                        ),
                        label: 'Balance',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(width: 12),
                      _Stat(
                        value: '${booking.upcomingBookings.length}',
                        label: 'Upcoming',
                        icon: Icons.schedule_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  // ── Preferences ─────────────────────────────────
                  SectionHeader(
                    eyebrowText: 'Preferences',
                    title: 'Your account',
                  ),
                  const SizedBox(height: 14),
                  PremiumCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SwitchRow(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifications',
                          subtitle: 'Booking confirmations and reminders',
                          value: _notifications,
                          onChanged: (v) =>
                              setState(() => _notifications = v),
                        ),
                        const Divider(height: 1, indent: 66),
                        _SwitchRow(
                          icon: Icons.dark_mode_outlined,
                          title: 'Dark mode',
                          subtitle: 'Switch to the noir palette',
                          value: theme.isDark,
                          onChanged: theme.toggleDark,
                        ),
                        const Divider(height: 1, indent: 66),
                        _MenuRow(
                          icon: Icons.credit_card_outlined,
                          title: 'Payment methods',
                          subtitle: 'Cards and wallet preferences',
                          onTap: () => _soon('Payment methods'),
                        ),
                        const Divider(height: 1, indent: 66),
                        _MenuRow(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'Theme, font size, notifications, legal',
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppConstants.routeSettings),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Support ─────────────────────────────────────
                  SectionHeader(
                    eyebrowText: 'Support',
                    title: 'Help & about',
                  ),
                  const SizedBox(height: 14),
                  PremiumCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _MenuRow(
                          icon: Icons.support_agent_rounded,
                          title: 'Help & support',
                          subtitle: 'Talk to our concierge team',
                          onTap: () => _soon('Concierge support'),
                        ),
                        const Divider(height: 1, indent: 66),
                        _MenuRow(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy & terms',
                          subtitle: 'How we handle your data',
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppConstants.routeSettings),
                        ),
                        const Divider(height: 1, indent: 66),
                        _MenuRow(
                          icon: Icons.insights_rounded,
                          title: 'Travel insights',
                          subtitle: 'Spending and booking trends',
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppConstants.routeAnalytics),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Lux.error,
                      side: BorderSide(
                          color: Lux.error.withValues(alpha: 0.5)),
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Log out'),
                    onPressed: _logout,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 17, color: Lux.goldDeep),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Lux.ivory
                    : Lux.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Lux.caption(context, size: 10.5)),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: _IconBox(icon: icon),
      title: Text(title, style: Lux.title(context, size: 14.5)),
      subtitle: Text(subtitle, style: Lux.caption(context, size: 11.5)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _IconBox(icon: icon),
      title: Text(title, style: Lux.title(context, size: 14.5)),
      subtitle: Text(subtitle, style: Lux.caption(context, size: 11.5)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Theme.of(context).dividerColor),
      onTap: onTap,
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Lux.gold.withValues(alpha: 0.12),
        border: Border.all(color: Lux.gold.withValues(alpha: 0.26)),
      ),
      child: Icon(icon, size: 18, color: Lux.goldDeep),
    );
  }
}
