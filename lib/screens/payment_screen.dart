import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/premium_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/booking_steps.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_fx.dart';
import '../widgets/responsive.dart';

/// Payment method selection with a staged processing sequence.
///
/// Card numbers are deliberately **not** collected here: the gateway
/// hosts its own PCI-compliant checkout, so raw PAN never touches the
/// app. Selecting Paystack therefore explains the hand-off instead of
/// rendering fields that would discard what the user typed.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'paystack'; // 'paystack' | 'wallet'
  int _stage = 0; // 0 idle, 1..3 processing, 4 done

  bool get _processing => _stage >= 1 && _stage <= 3;

  Future<void> _pay() async {
    final booking = context.read<BookingProvider>();
    final auth = context.read<AuthProvider>();

    if (_method == 'wallet' &&
        (auth.user?.balance ?? 0) < booking.totalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Wallet balance is too low — top up or pay by card.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Lux.error,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _stage = 1);
    // Staged feedback: contacting gateway → verifying → confirming.
    for (var s = 2; s <= 3; s++) {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      setState(() => _stage = s);
    }

    final ok = await booking.pay(method: _method, authToken: auth.token);
    if (!mounted) return;
    if (!ok) {
      setState(() => _stage = 0);
      _fail(booking.errorMessage ?? 'Payment could not be completed');
      return;
    }

    final confirmed = await booking.confirmBooking(authToken: auth.token);
    if (!mounted) return;
    setState(() => _stage = 4);
    if (!confirmed) {
      _fail(booking.errorMessage ?? 'Booking failed after payment');
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacementNamed(AppConstants.routeBookingConfirmation);
  }

  void _fail(String message) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Lux.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final auth = context.watch<AuthProvider>();
    final isPhone = Breakpoints.isPhone(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletBalance = auth.user?.balance ?? 0;
    final walletCovers = walletBalance >= booking.totalPrice;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Column(
        children: [
          const BookingSteps(current: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                // ── Amount ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Lux.rLg),
                    gradient: Lux.metallic,
                    boxShadow: Lux.floating,
                    border:
                        Border.all(color: Lux.gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'AMOUNT DUE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                          color: Lux.ivory.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedCounter(
                        value: booking.totalPrice,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 42,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          color: Lux.ivory,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        booking.selectedSeats.isEmpty
                            ? 'No seats selected'
                            : '${booking.selectedSeats.length} seat'
                                '${booking.selectedSeats.length == 1 ? '' : 's'}'
                                ' · ${booking.selectedSeats.join(', ')}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Lux.ivory.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                // ── Breakdown ────────────────────────────────────
                PremiumCard(
                  child: Column(
                    children: [
                      _line(context, 'Fare per seat',
                          Formatters.currency(booking.selectedTrip?.fare ?? 0,
                              withDecimals: false)),
                      const SizedBox(height: 10),
                      _line(context, 'Seats',
                          '${booking.selectedSeats.length}'),
                      const Divider(height: 24),
                      _line(
                        context,
                        'Total',
                        Formatters.currency(booking.totalPrice,
                            withDecimals: false),
                        emphasise: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Eyebrow('Payment method'),
                const SizedBox(height: 12),
                _MethodTile(
                  selected: _method == 'paystack',
                  icon: Icons.credit_card_rounded,
                  title: 'Card · Paystack',
                  subtitle: 'Secure hosted checkout — Visa, Mastercard, USSD',
                  enabled: !_processing,
                  onTap: () => setState(() => _method = 'paystack'),
                ),
                const SizedBox(height: 12),
                _MethodTile(
                  selected: _method == 'wallet',
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Swift Fleet wallet',
                  subtitle: 'Available ${Formatters.currency(walletBalance, withDecimals: false)}'
                      '${walletCovers ? '' : ' — not enough for this booking'}',
                  enabled: !_processing,
                  warning: !walletCovers,
                  onTap: () => setState(() => _method = 'wallet'),
                ),
                const SizedBox(height: 18),
                // ── Hand-off explainer ────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: _method == 'paystack'
                      ? _HandoffNote(
                          key: const ValueKey('paystack-note'),
                          text:
                              'You will complete payment on Paystack’s secure page. '
                              'Card details are never stored by Swift Fleet.',
                        )
                      : _HandoffNote(
                          key: const ValueKey('wallet-note'),
                          text: walletCovers
                              ? 'The fare is deducted from your wallet immediately.'
                              : 'Top up your wallet first, or switch to card payment.',
                          warning: !walletCovers,
                        ),
                ),
                if (_processing) ...[
                  const SizedBox(height: 22),
                  _ProcessingSteps(stage: _stage),
                ],
                if (booking.payment != null) ...[
                  const SizedBox(height: 18),
                  PremiumCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Lux.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long_rounded,
                              size: 19, color: Lux.success),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payment reference',
                                  style: Lux.title(context, size: 13.5)),
                              const SizedBox(height: 2),
                              SelectableText(
                                booking.payment!.paymentReference,
                                style: Lux.caption(context, size: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const _SecureBadges(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? Lux.darkCard : Lux.cardLight,
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: ContentShell(
              maxWidth: isPhone ? 720 : 860,
              padding: EdgeInsets.zero,
              child: PremiumButton(
                label: _processing
                    ? 'Processing…'
                    : 'Pay ${Formatters.currency(booking.totalPrice, withDecimals: false)}',
                icon: Icons.lock_rounded,
                loading: _processing || booking.isProcessing,
                onPressed:
                    _processing || booking.isProcessing ? null : _pay,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value,
      {bool emphasise = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          label,
          style: emphasise
              ? Lux.title(context, size: 14.5)
              : Lux.body(context, size: 13.5),
        ),
        const Spacer(),
        Text(
          value,
          style: emphasise
              ? GoogleFonts.playfairDisplay(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Lux.goldBright : Lux.ink,
                )
              : Lux.title(context, size: 14),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool warning;
  final VoidCallback onTap;

  const _MethodTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Lux.rMd),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Lux.rMd),
            border: Border.all(
              color: selected
                  ? Lux.gold
                  : (isDark ? Lux.hairlineDark : Lux.hairlineLight),
              width: selected ? 1.8 : 1,
            ),
            color: selected
                ? Lux.gold.withValues(alpha: isDark ? 0.1 : 0.06)
                : (isDark ? Lux.darkCard : Lux.cardLight),
            boxShadow: selected ? Lux.soft : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: selected ? Lux.goldGradient : null,
                  color: selected
                      ? null
                      : Lux.gold.withValues(alpha: 0.12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? Lux.ink
                      : (isDark ? Lux.goldBright : Lux.goldDeep),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Lux.title(context, size: 14.5)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Lux.caption(context, size: 11.5).copyWith(
                        color: warning ? Lux.warning : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? Lux.gold
                        : (isDark ? Lux.hairlineDark : Lux.hairlineLight),
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Center(
                        child: Icon(Icons.check_rounded,
                            size: 13, color: Lux.goldDeep),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandoffNote extends StatelessWidget {
  final String text;
  final bool warning;

  const _HandoffNote({
    super.key,
    required this.text,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? Lux.warning : Lux.success;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(warning ? Icons.info_outline_rounded : Icons.verified_user_outlined,
            size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Lux.caption(context, size: 11.5).copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _SecureBadges extends StatelessWidget {
  const _SecureBadges();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: const [
        _Badge(icon: Icons.lock_rounded, label: 'TLS encrypted'),
        _Badge(icon: Icons.shield_outlined, label: 'PCI-DSS compliant'),
        _Badge(icon: Icons.undo_rounded, label: 'Instant refund policy'),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Lux.hairlineDark : Lux.hairlineLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: isDark ? Lux.textOnDarkMuted : Lux.ink.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(label, style: Lux.caption(context, size: 10.5)),
        ],
      ),
    );
  }
}

class _ProcessingSteps extends StatelessWidget {
  final int stage;

  const _ProcessingSteps({required this.stage});

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Contacting the gateway…',
      'Verifying payment…',
      'Reserving your seats…',
    ];
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Securing your booking'),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: (i + 1) < stage
                        ? const Icon(Icons.check_circle_rounded,
                            size: 21, color: Lux.success)
                        : (i + 1) == stage
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation(Lux.gold),
                                ),
                              )
                            : Icon(Icons.radio_button_unchecked_rounded,
                                size: 20,
                                color: Theme.of(context).dividerColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: Lux.body(context, size: 13.5).copyWith(
                        color: (i + 1) <= stage
                            ? null
                            : Lux.caption(context).color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
