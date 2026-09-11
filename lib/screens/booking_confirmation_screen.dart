import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/premium_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../services/notification_service.dart';
import '../services/ticket_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/booking_steps.dart';
import '../widgets/feedback.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_fx.dart';
import '../widgets/responsive.dart';

/// Celebration + e-ticket: confetti, a drawn success mark, the booking
/// reference, a scannable QR and the PDF / share actions.
class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key});

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    // Queue an inbox notification for the confirmed booking.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final booking = context.read<BookingProvider>();
      final ref = booking.bookingReference ?? booking.payment?.paymentReference;
      if (ref != null) {
        context.read<NotificationService>().push(
              'Booking confirmed',
              'Reference $ref — show your QR at boarding.',
            );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyReference(String ref) {
    Clipboard.setData(ClipboardData(text: ref));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking reference copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Generates the PDF e-ticket and opens the OS share sheet.
  Future<void> _sharePdf(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final booking = context.read<BookingProvider>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TicketService.shareTicket(
        bookings: booking.confirmedBookings.isEmpty
            ? booking.recentBookings
                .take(booking.selectedSeats.length)
                .toList()
            : booking.confirmedBookings,
        trip: booking.selectedTrip,
        amount: booking.payment?.amount ?? booking.totalPrice,
        passengerName: auth.user?.customerName ?? 'Passenger',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.friendly(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _done() {
    HapticFeedback.mediumImpact();
    context.read<BookingProvider>().resetFlow();
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppConstants.routeHome,
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final trip = booking.selectedTrip;
    final ref = booking.bookingReference ??
        booking.payment?.paymentReference ??
        'N/A';
    final isPhone = Breakpoints.isPhone(context);

    return Scaffold(
      body: ConfettiBurst(
        child: SafeArea(
          child: Column(
            children: [
              const BookingSteps(current: 3),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    // ── Success mark ──────────────────────────────
                    Center(
                      child: FadeTransition(
                        opacity: _controller,
                        child: const AnimatedSuccessMark(size: 116),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'You’re booked',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Lux.ivory
                                  : Lux.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Your seat is confirmed. Present the QR below '
                              'when you board.',
                              textAlign: TextAlign.center,
                              style: Lux.body(context, size: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ── Reference ─────────────────────────────────
                    _ReferenceCard(
                      reference: ref,
                      onCopy: () => _copyReference(ref),
                    ),
                    const SizedBox(height: 16),
                    // ── QR ────────────────────────────────────────
                    _QrCard(reference: ref),
                    const SizedBox(height: 16),
                    // ── Itinerary ─────────────────────────────────
                    if (trip != null) _ItineraryCard(booking: booking),
                    const SizedBox(height: 24),
                    // ── Actions ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: GhostButton(
                            label: 'PDF ticket',
                            icon: Icons.picture_as_pdf_rounded,
                            onPressed: () => _sharePdf(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GhostButton(
                            label: 'Share',
                            icon: Icons.ios_share_rounded,
                            onPressed: () => _copyReference(ref),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GhostButton(
                      label: 'Add to calendar',
                      icon: Icons.event_available_outlined,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Calendar sync is coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    ContentShell(
                      maxWidth: isPhone ? 720 : 860,
                      padding: EdgeInsets.zero,
                      child: PremiumButton(
                        label: 'Back to home',
                        icon: Icons.home_rounded,
                        onPressed: _done,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  final String reference;
  final VoidCallback onCopy;

  const _ReferenceCard({required this.reference, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Booking reference'),
                const SizedBox(height: 8),
                Text(
                  reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Lux.goldBright
                        : Lux.ink,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Lux.gold.withValues(alpha: 0.12),
                  border: Border.all(color: Lux.gold.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.copy_rounded,
                    size: 17, color: Lux.goldDeep),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String reference;

  const _QrCard({required this.reference});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      border: Border.all(color: Lux.gold.withValues(alpha: 0.45), width: 1.4),
      child: Row(
        children: [
          Semantics(
            label: 'Ticket QR code for booking $reference',
            child: Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Lux.gold.withValues(alpha: 0.4)),
              ),
              child: QrImageView(
                data: reference,
                version: QrVersions.auto,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Lux.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Lux.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Boarding pass'),
                const SizedBox(height: 8),
                Text('Show this at the gate',
                    style: Lux.title(context, size: 14.5)),
                const SizedBox(height: 5),
                Text(
                  'Our crew will scan the code to check you in. '
                  'Keep your screen brightness up.',
                  style: Lux.caption(context, size: 11.5).copyWith(
                    color: isDark ? null : Lux.ink.withValues(alpha: 0.55),
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

class _ItineraryCard extends StatelessWidget {
  final BookingProvider booking;

  const _ItineraryCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final trip = booking.selectedTrip!;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Itinerary'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(trip.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Lux.title(context, size: 15.5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Lux.goldDeep),
              ),
              Expanded(
                child: Text(
                  trip.destination,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lux.title(context, size: 15.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(context, Icons.schedule_rounded, 'Departure',
              '${Formatters.date(trip.departureDate)} · '
              '${Formatters.time(trip.departureTime)}'),
          if (trip.assetName.isNotEmpty)
            _row(context, Icons.directions_bus_filled_rounded, 'Vehicle',
                '${trip.assetName}${trip.vehicleRegNo.isEmpty ? '' : ' · ${trip.vehicleRegNo}'}'),
          if (trip.driverName.isNotEmpty)
            _row(context, Icons.person_outline_rounded, 'Chauffeur',
                trip.driverName),
          _row(context, Icons.event_seat_rounded, 'Seats',
              booking.selectedSeats.join(', ')),
          const Divider(height: 26),
          Row(
            children: [
              Text('Total paid', style: Lux.body(context, size: 13.5)),
              const Spacer(),
              Text(
                Formatters.currency(
                    booking.payment?.amount ?? booking.totalPrice,
                    withDecimals: false),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Lux.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Lux.caption(context).color),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(label, style: Lux.caption(context, size: 12)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: Lux.title(context, size: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
