import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/premium_theme.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/premium_bottom_sheet.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_fx.dart';
import '../widgets/premium_input.dart';
import '../widgets/premium_loader.dart';
import '../widgets/responsive.dart';

/// Wallet balance, top-up and the transaction ledger.
class WalletScreen extends StatefulWidget {
  /// When true, renders without its own Scaffold.
  final bool embedded;

  const WalletScreen({super.key, this.embedded = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  /// Local ledger filter — 'all' | 'credit' | 'debit'.
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    return context.read<BookingProvider>().loadWallet(
          customerId: user?.customerId ?? '',
          customerName: user?.customerName ?? '',
          authToken: auth.token,
        );
  }

  List<WalletTransaction> _filtered(List<WalletTransaction> all) {
    switch (_filter) {
      case 'credit':
        return all.where((t) => t.isCredit).toList();
      case 'debit':
        return all.where((t) => !t.isCredit).toList();
      default:
        return all;
    }
  }

  void _showTopUp() {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final quickAmounts = [2000.0, 5000.0, 10000.0, 25000.0];

    showPremiumBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SheetBody(
            title: 'Add money',
            subtitle: 'Fund your wallet instantly through Paystack.',
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumTextField(
                    controller: amountController,
                    label: 'Amount (₦)',
                    hint: 'e.g. 5000',
                    prefixIcon: Icons.payments_outlined,
                    keyboardType: TextInputType.number,
                    validator: Validators.amount,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickAmounts.map((amount) {
                      return _QuickAmount(
                        label: Formatters.currency(amount, withDecimals: false),
                        selected:
                            amountController.text.trim() == amount.toStringAsFixed(0),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          amountController.text = amount.toStringAsFixed(0);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Consumer<BookingProvider>(
                    builder: (_, booking, _) => PremiumButton(
                      label: 'Top up wallet',
                      icon: Icons.add_rounded,
                      loading: booking.isProcessing,
                      onPressed: booking.isProcessing
                          ? null
                          : () async {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              final auth = context.read<AuthProvider>();
                              final ok = await booking.fundWallet(
                                amount:
                                    double.parse(amountController.text.trim()),
                                customerId: auth.user?.customerId ?? '',
                                customerName: auth.user?.customerName ?? '',
                                authToken: auth.token,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'Wallet topped up'
                                        : booking.errorMessage ??
                                            'Top-up failed'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor:
                                        ok ? Lux.success : Lux.error,
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: body,
    );
  }

  Widget _body() {
    final booking = context.watch<BookingProvider>();
    final isPhone = Breakpoints.isPhone(context);
    final items = _filtered(booking.transactions);

    return RefreshIndicator(
      onRefresh: _load,
      child: ContentShell(
        maxWidth: isPhone ? 720 : 860,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ── Metallic balance card ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Lux.rXl),
                gradient: Lux.metallic,
                boxShadow: Lux.floating,
                border: Border.all(color: Lux.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 17, color: Lux.goldBright),
                      const SizedBox(width: 8),
                      Text(
                        'AVAILABLE BALANCE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          color: Lux.ivory.withValues(alpha: 0.78),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'SWIFT FLEET',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Lux.gold.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: booking.walletLoading && booking.walletBalance == 0
                        ? const SizedBox(
                            height: 40,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor:
                                      AlwaysStoppedAnimation(Lux.goldBright),
                                ),
                              ),
                            ),
                          )
                        : AnimatedCounter(
                            key: ValueKey(booking.walletBalance),
                            value: booking.walletBalance,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 42,
                              fontWeight: FontWeight.w600,
                              height: 1,
                              color: Lux.ivory,
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Member since your first journey',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: Lux.ivory.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      _TopUpPill(onTap: _showTopUp),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // ── Ledger ────────────────────────────────────────────
            SectionHeader(
              eyebrowText: 'Activity',
              title: 'Transactions',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                _FilterChip(
                  label: 'Credit',
                  selected: _filter == 'credit',
                  onTap: () => setState(() => _filter = 'credit'),
                ),
                _FilterChip(
                  label: 'Debit',
                  selected: _filter == 'debit',
                  onTap: () => setState(() => _filter = 'debit'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (booking.walletLoading && booking.transactions.isEmpty)
              ...List.generate(3, (_) => const _TxnSkeleton())
            else if (items.isEmpty)
              _emptyState(booking)
            else
              PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 74),
                      _TransactionRow(txn: items[i]),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BookingProvider booking) {
    return PremiumCard(
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Lux.gold.withValues(alpha: 0.1),
              border: Border.all(color: Lux.gold.withValues(alpha: 0.32)),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 30, color: Lux.goldDeep),
          ),
          const SizedBox(height: 18),
          Text(
            _filter == 'all' ? 'No transactions yet' : 'Nothing to show here',
            style: Lux.headline(context, size: 19),
          ),
          const SizedBox(height: 6),
          Text(
            _filter == 'all'
                ? 'Top up your wallet and your activity will appear here.'
                : 'Try a different filter to see more activity.',
            textAlign: TextAlign.center,
            style: Lux.body(context, size: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: PremiumButton(
              label: 'Add money',
              icon: Icons.add_rounded,
              onPressed: _showTopUp,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUpPill extends StatelessWidget {
  final VoidCallback onTap;

  const _TopUpPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: Lux.goldGradient,
            boxShadow: Lux.goldGlow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: Lux.ink),
              const SizedBox(width: 5),
              Text(
                'Top up',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Lux.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final WalletTransaction txn;

  const _TransactionRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final credit = txn.isCredit;
    final color = credit ? Lux.success : Lux.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(
              credit
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description.isEmpty ? 'Transaction' : txn.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lux.title(context, size: 14),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      Formatters.date(txn.date),
                      style: Lux.caption(context, size: 11),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (txn.isCompleted ? Lux.success : Lux.warning)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(txn.status),
                        style: Lux.caption(context, size: 9.5).copyWith(
                          color: txn.isCompleted ? Lux.success : Lux.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${credit ? '+' : '−'}'
            '${Formatters.currency(txn.amount, withDecimals: false)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String s) {
    if (s.isEmpty) return 'Completed';
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? Lux.goldGradient : null,
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark ? Lux.hairlineDark : Lux.hairlineLight),
            ),
          ),
          child: Text(
            label,
            style: Lux.caption(context, size: 12.5).copyWith(
              color: selected
                  ? Lux.ink
                  : (isDark ? Lux.textOnDark : Lux.ink),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAmount extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickAmount({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? Lux.gold.withValues(alpha: 0.16) : null,
            border: Border.all(
              color: selected
                  ? Lux.gold
                  : (isDark ? Lux.hairlineDark : Lux.hairlineLight),
            ),
          ),
          child: Text(
            label,
            style: Lux.caption(context, size: 12).copyWith(
              color: selected
                  ? Lux.goldDeep
                  : (isDark ? Lux.textOnDark : Lux.ink),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TxnSkeleton extends StatelessWidget {
  const _TxnSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: ShimmerBox(height: 72, radius: BorderRadius.all(Radius.circular(Lux.rLg))),
    );
  }
}
