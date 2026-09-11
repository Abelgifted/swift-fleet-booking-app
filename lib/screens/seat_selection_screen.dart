import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/premium_theme.dart';
import '../models/seat.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_fx.dart';
import '../widgets/premium_loader.dart';
import '../widgets/responsive.dart';

/// Visual coach seat map: pinch-to-zoom, an elegant legend, animated
/// gold selection and a live-price action bar.
class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final booking = context.read<BookingProvider>();
      if (booking.seats.isEmpty && !booking.seatsLoading) {
        booking.loadSeats(authToken: context.read<AuthProvider>().token);
      }
    });
  }

  Future<void> _refresh() => context.read<BookingProvider>().loadSeats(
        authToken: context.read<AuthProvider>().token,
      );

  void _tapSeat(BookingProvider booking, Seat seat) {
    if (!seat.isSelectable) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            seat.isDriverSeat
                ? 'That is the driver’s seat.'
                : 'Seat ${seat.seatNumber} is no longer available.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    final msg = booking.toggleSeat(seat.seatNumber);
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _continue() async {
    final booking = context.read<BookingProvider>();
    if (booking.selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one seat to continue'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final ok = await booking.holdSelectedSeats(
      authToken: context.read<AuthProvider>().token,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(booking.errorMessage ?? 'Unable to hold those seats'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Lux.error,
        ),
      );
      return;
    }
    Navigator.of(context).pushNamed(AppConstants.routePassenger);
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final trip = booking.selectedTrip;
    final isPhone = Breakpoints.isPhone(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose your seats')),
      body: Column(
        children: [
          if (trip != null) _TripBand(booking: booking),
          const _Legend(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: booking.seatsLoading && booking.seats.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [_SeatMapSkeleton()],
                    )
                  : booking.seats.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Lux.gold.withValues(alpha: 0.1),
                                  border: Border.all(
                                      color: Lux.gold.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.event_seat_outlined,
                                    size: 32, color: Lux.goldDeep),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text('No seat map available',
                                textAlign: TextAlign.center,
                                style: Lux.headline(context, size: 19)),
                            const SizedBox(height: 6),
                            Text('Pull down to try again.',
                                textAlign: TextAlign.center,
                                style: Lux.body(context, size: 13)),
                          ],
                        )
                      : Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: InteractiveViewer(
                              minScale: 0.7,
                              maxScale: 2.6,
                              boundaryMargin: const EdgeInsets.all(48),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: isPhone ? 340 : 400,
                                  ),
                                  child: _CoachFrame(
                                    seats: booking.seats,
                                    isSelected: booking.isSeatSelected,
                                    onTap: (s) => _tapSeat(booking, s),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ),
          _ActionBar(onContinue: _continue),
        ],
      ),
    );
  }
}

// ── Trip band ─────────────────────────────────────────────────────

class _TripBand extends StatelessWidget {
  final BookingProvider booking;

  const _TripBand({required this.booking});

  @override
  Widget build(BuildContext context) {
    final trip = booking.selectedTrip;
    if (trip == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        gradient: isDark ? Lux.inkGradient : Lux.goldGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trip.source} → ${trip.destination}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Lux.ivory : Lux.ink,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 13,
                  color: (isDark ? Lux.ivory : Lux.ink)
                      .withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${Formatters.date(trip.departureDate)} • '
                  '${Formatters.time(trip.departureTime)}'
                  '${trip.assetName.isEmpty ? '' : ' • ${trip.assetName}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: (isDark ? Lux.ivory : Lux.ink)
                        .withValues(alpha: 0.72),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: const [
          _LegendItem(seatState: _SeatState.available, label: 'Available'),
          _LegendItem(seatState: _SeatState.selected, label: 'Selected'),
          _LegendItem(seatState: _SeatState.booked, label: 'Booked'),
          _LegendItem(seatState: _SeatState.held, label: 'On hold'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final _SeatState seatState;
  final String label;

  const _LegendItem({required this.seatState, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _fill(seatState),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _border(seatState), width: 1.4),
            boxShadow: seatState == _SeatState.selected
                ? [
                    BoxShadow(
                      color: Lux.gold.withValues(alpha: 0.5),
                      blurRadius: 7,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Lux.caption(context, size: 11.5)),
      ],
    );
  }
}

// ── Coach frame ───────────────────────────────────────────────────

class _CoachFrame extends StatelessWidget {
  final List<Seat> seats;
  final bool Function(String) isSelected;
  final ValueChanged<Seat> onTap;

  const _CoachFrame({
    required this.seats,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driver = seats.where((s) => s.isDriverSeat).toList();
    final rest = seats.where((s) => !s.isDriverSeat).toList()
      ..sort((a, b) => _seatKey(a).compareTo(_seatKey(b)));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
      decoration: BoxDecoration(
        color: isDark ? Lux.darkCard : Lux.cardLight,
        borderRadius: BorderRadius.circular(52),
        border: Border.all(
          color: isDark
              ? Lux.gold.withValues(alpha: 0.35)
              : Lux.gold.withValues(alpha: 0.45),
          width: 1.6,
        ),
        boxShadow: Lux.floating,
      ),
      child: Column(
        children: [
          // Windshield.
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(34)),
              gradient: LinearGradient(
                colors: isDark
                    ? [Lux.inkSoft, Lux.ink]
                    : [Lux.cream, Lux.hairlineLight],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.airline_seat_recline_extra_rounded,
                size: 18,
                color: (isDark ? Lux.goldBright : Lux.goldDeep)
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('CABIN',
                  style: Lux.caption(context, size: 9.5).copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              if (driver.isNotEmpty)
                _SeatBox(seat: driver.first, selected: false, onTap: (_) {})
              else
                const SizedBox(width: 46),
              const SizedBox(width: 12),
              Icon(Icons.directions_car_filled_rounded,
                  size: 20,
                  color: (isDark ? Lux.textOnDarkMuted : Lux.ink)
                      .withValues(alpha: 0.4)),
            ],
          ),
          Divider(height: 30, color: Theme.of(context).dividerColor),
          // 2 + aisle + 2 grid.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _gridCount(rest.length),
            itemBuilder: (context, i) {
              final pos = i % 5;
              if (pos == 2) return const SizedBox(); // aisle
              final seatIndex = (i ~/ 5) * 4 + (pos > 2 ? pos - 1 : pos);
              if (seatIndex >= rest.length) return const SizedBox();
              final seat = rest[seatIndex];
              return _SeatBox(
                seat: seat,
                selected: isSelected(seat.seatNumber),
                onTap: onTap,
              );
            },
          ),
        ],
      ),
    );
  }

  static int _seatKey(Seat s) => int.tryParse(s.seatNumber) ?? 1 << 20;

  static int _gridCount(int n) => (n / 4).ceil() * 5;
}

// ── Seat ──────────────────────────────────────────────────────────

enum _SeatState { available, selected, booked, held, driver }

Color _fill(_SeatState s) {
  switch (s) {
    case _SeatState.available:
      return Colors.transparent;
    case _SeatState.selected:
      return Lux.gold;
    case _SeatState.booked:
      return Lux.seatBooked;
    case _SeatState.held:
      return Lux.seatHeld;
    case _SeatState.driver:
      return Lux.driverSeat;
  }
}

Color _border(_SeatState s) {
  switch (s) {
    case _SeatState.available:
      return Lux.gold.withValues(alpha: 0.75);
    case _SeatState.selected:
      return Lux.goldBright;
    case _SeatState.booked:
      return Lux.seatBooked;
    case _SeatState.held:
      return Lux.warning.withValues(alpha: 0.6);
    case _SeatState.driver:
      return Lux.driverSeat;
  }
}

class _SeatBox extends StatelessWidget {
  final Seat seat;
  final bool selected;
  final ValueChanged<Seat> onTap;

  const _SeatBox({
    required this.seat,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (seat.isDriverSeat) {
      return Semantics(
        label: 'Driver seat',
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Lux.driverSeat,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Lux.seatBooked.withValues(alpha: 0.5)),
          ),
          child: const Icon(Icons.directions_car_filled_rounded,
              size: 20, color: Lux.ink),
        ),
      );
    }

    final _SeatState state;
    if (selected) {
      state = _SeatState.selected;
    } else if (!seat.isSelectable) {
      state = seat.isHeld ? _SeatState.held : _SeatState.booked;
    } else {
      state = _SeatState.available;
    }

    final label = switch (state) {
      _SeatState.selected => 'selected',
      _SeatState.held => 'on hold',
      _SeatState.booked => 'booked',
      _ => 'available',
    };

    final textColor = switch (state) {
      _SeatState.selected => Lux.ink,
      _SeatState.available => isDark ? Lux.goldBright : Lux.goldDeep,
      _SeatState.held => Lux.ink,
      _ => Colors.white,
    };

    return Semantics(
      button: true,
      enabled: seat.isSelectable,
      label: 'Seat ${seat.seatNumber}, $label',
      child: GestureDetector(
        onTap: () => onTap(seat),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          decoration: BoxDecoration(
            color: _fill(state),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _border(state),
              width: state == _SeatState.selected ? 2 : 1.3,
            ),
            boxShadow: state == _SeatState.selected
                ? [
                    BoxShadow(
                      color: Lux.gold.withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedScale(
              scale: state == _SeatState.selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 220),
              child: state == _SeatState.booked
                  ? const Icon(Icons.lock_rounded, size: 15, color: Colors.white)
                  : Text(
                      seat.seatNumber,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action bar ────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final VoidCallback onContinue;

  const _ActionBar({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final count = booking.selectedSeats.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Lux.darkCard : Lux.cardLight,
        border: Border(
          top: BorderSide(
            color: isDark ? Lux.hairlineDark : Lux.hairlineLight,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Lux.ink.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0
                          ? 'No seats selected'
                          : '$count seat${count == 1 ? '' : 's'} · '
                              '${booking.selectedSeats.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Lux.caption(context, size: 12),
                    ),
                    const SizedBox(height: 2),
                    AnimatedCounter(
                      value: booking.totalPrice,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: isDark ? Lux.goldBright : Lux.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 172,
                child: PremiumButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  loading: booking.isProcessing,
                  onPressed:
                      count == 0 || booking.isProcessing ? null : onContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatMapSkeleton extends StatelessWidget {
  const _SeatMapSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShimmerBox(height: 420, radius: BorderRadius.circular(52)),
        const SizedBox(height: 16),
        const ShimmerBox(height: 16, width: 200),
      ],
    );
  }
}
