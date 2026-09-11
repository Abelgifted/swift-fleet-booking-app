import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/premium_theme.dart';
import '../providers/app_settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../utils/app_copy.dart';
import '../utils/constants.dart';
import '../widgets/api_status.dart';
import '../widgets/premium_bottom_sheet.dart';
import '../widgets/premium_card.dart';
import '../widgets/responsive.dart';

/// App-level settings: appearance, accessibility, notifications, legal.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final notifications = context.watch<NotificationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPhone = Breakpoints.isPhone(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ContentShell(
        maxWidth: isPhone ? 720 : 860,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Group(
              eyebrow: 'Appearance',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _IconBox(icon: Icons.brightness_6_outlined),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Theme',
                                    style: Lux.title(context, size: 14.5)),
                                const SizedBox(height: 2),
                                Text('Light, dark or follow your system',
                                    style: Lux.caption(context, size: 11.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ThemeSegments(
                        mode: theme.mode,
                        onChanged: theme.setMode,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 70),
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: const _IconBox(icon: Icons.contrast_rounded),
                  title: Text('High contrast',
                      style: Lux.title(context, size: 14.5)),
                  subtitle: Text('Stronger text and borders',
                      style: Lux.caption(context, size: 11.5)),
                  value: settings.highContrast,
                  onChanged: settings.setHighContrast,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Group(
              eyebrow: 'Accessibility',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _IconBox(icon: Icons.text_fields_rounded),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Text size',
                                    style: Lux.title(context, size: 14.5)),
                                const SizedBox(height: 2),
                                Text(
                                  '${(settings.fontScale * 100).round()}% of default',
                                  style: Lux.caption(context, size: 11.5),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Aa',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16 * settings.fontScale,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Lux.goldBright : Lux.goldDeep,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Lux.gold,
                          inactiveTrackColor:
                              Lux.gold.withValues(alpha: 0.2),
                          thumbColor: Lux.goldBright,
                          overlayColor: Lux.gold.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: settings.fontScale,
                          min: 0.85,
                          max: 1.3,
                          divisions: 9,
                          label: '${(settings.fontScale * 100).round()}%',
                          onChanged: settings.setFontScale,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Group(
              eyebrow: 'Notifications',
              children: [
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: const _IconBox(icon: Icons.notifications_outlined),
                  title: Text('Booking alerts',
                      style: Lux.title(context, size: 14.5)),
                  subtitle: Text(
                    notifications.permissionGranted
                        ? 'Enabled on this device'
                        : 'Tap to enable on this device',
                    style: Lux.caption(context, size: 11.5),
                  ),
                  value: notifications.enabled,
                  onChanged: (v) async {
                    if (v) {
                      await notifications.requestPermission();
                    }
                    await notifications.setEnabled(v);
                  },
                ),
                const Divider(height: 1, indent: 70),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const _IconBox(icon: Icons.inbox_outlined),
                  title: Text('Notification inbox',
                      style: Lux.title(context, size: 14.5)),
                  subtitle: Text(
                    notifications.unreadCount > 0
                        ? '${notifications.unreadCount} unread'
                        : 'All caught up',
                    style: Lux.caption(context, size: 11.5),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: Theme.of(context).dividerColor),
                  onTap: () => _openInbox(context, notifications),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Group(
              eyebrow: 'Diagnostics',
              children: [
                ApiStatusTile(
                  onOpenDiagnostics: () => Navigator.of(context)
                      .pushNamed(AppConstants.routeApiDiagnostics),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Group(
              eyebrow: 'About',
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const _IconBox(icon: Icons.info_outline_rounded),
                  title: Text('App info',
                      style: Lux.title(context, size: 14.5)),
                  subtitle: Text('Swift Fleet v${AppCopy.version}',
                      style: Lux.caption(context, size: 11.5)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: Theme.of(context).dividerColor),
                  onTap: () =>
                      _openDoc(context, 'About Swift Fleet', AppCopy.about),
                ),
                const Divider(height: 1, indent: 70),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading:
                      const _IconBox(icon: Icons.description_outlined),
                  title: Text('Terms & conditions',
                      style: Lux.title(context, size: 14.5)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: Theme.of(context).dividerColor),
                  onTap: () =>
                      _openDoc(context, 'Terms & Conditions', AppCopy.terms),
                ),
                const Divider(height: 1, indent: 70),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const _IconBox(icon: Icons.privacy_tip_outlined),
                  title: Text('Privacy policy',
                      style: Lux.title(context, size: 14.5)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: Theme.of(context).dividerColor),
                  onTap: () =>
                      _openDoc(context, 'Privacy Policy', AppCopy.privacy),
                ),
                const Divider(height: 1, indent: 70),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const _IconBox(icon: Icons.code_rounded),
                  title: Text('Open source licences',
                      style: Lux.title(context, size: 14.5)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: Theme.of(context).dividerColor),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: AppCopy.version,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: Column(
                children: [
                  Text(
                    AppConstants.appName.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: isDark ? Lux.goldBright : Lux.goldDeep,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Travel in luxury',
                      style: Lux.caption(context, size: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDoc(BuildContext context, String title, String body) {
    showPremiumBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(title, style: Lux.headline(context, size: 23)),
            const SizedBox(height: 14),
            const GoldDivider(),
            const SizedBox(height: 18),
            Text(body, style: Lux.body(context, size: 13.5)),
          ],
        ),
      ),
    );
  }

  void _openInbox(BuildContext context, NotificationService service) {
    showPremiumBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SheetBody(
        title: 'Inbox',
        subtitle: service.inbox.isEmpty
            ? null
            : '${service.inbox.length} notification'
                '${service.inbox.length == 1 ? '' : 's'}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (service.inbox.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Lux.gold.withValues(alpha: 0.1),
                        border:
                            Border.all(color: Lux.gold.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.notifications_none_rounded,
                          size: 26, color: Lux.goldDeep),
                    ),
                    const SizedBox(height: 16),
                    Text('Nothing here yet',
                        style: Lux.headline(context, size: 18)),
                    const SizedBox(height: 6),
                    Text(
                      'Booking confirmations will appear here.',
                      textAlign: TextAlign.center,
                      style: Lux.body(context, size: 13),
                    ),
                  ],
                ),
              )
            else ...[
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: service.inbox.length,
                  itemBuilder: (_, i) {
                    final n = service.inbox[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IconBox(
                              icon: n.read
                                  ? Icons.notifications_none_rounded
                                  : Icons.notifications_active_rounded,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title,
                                      style: Lux.title(context, size: 14)),
                                  const SizedBox(height: 3),
                                  Text(n.body,
                                      style: Lux.caption(context, size: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  service.markAllRead();
                  Navigator.of(context).pop();
                },
                child: const Text('Mark all as read'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Segmented light / system / dark picker with a gold selection.
class _ThemeSegments extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSegments({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const options = <(ThemeMode, IconData, String)>[
      (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
      (ThemeMode.system, Icons.settings_suggest_outlined, 'System'),
      (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
    ];
    return Row(
      children: [
        for (final (value, icon, label) in options) ...[
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Lux.rSm),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Lux.rSm),
                    gradient: mode == value ? Lux.goldGradient : null,
                    border: Border.all(
                      color: mode == value
                          ? Colors.transparent
                          : (isDark ? Lux.hairlineDark : Lux.hairlineLight),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: mode == value
                            ? Lux.ink
                            : (isDark ? Lux.textOnDarkMuted : Lux.ink)
                                .withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        style: Lux.caption(context, size: 11).copyWith(
                          color: mode == value
                              ? Lux.ink
                              : (isDark ? Lux.textOnDark : Lux.ink),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (value != options.last.$1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String eyebrow;
  final List<Widget> children;

  const _Group({required this.eyebrow, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(eyebrow),
        const SizedBox(height: 10),
        PremiumCard(padding: EdgeInsets.zero, child: Column(children: children)),
      ],
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
