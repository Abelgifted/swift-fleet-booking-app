import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/premium_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/booking_steps.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_input.dart';
import '../widgets/responsive.dart';

/// Passenger form, next-of-kin block and a trip summary → payment.
class PassengerDetailsScreen extends StatefulWidget {
  const PassengerDetailsScreen({super.key});

  @override
  State<PassengerDetailsScreen> createState() =>
      _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState extends State<PassengerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _nok = TextEditingController();
  final _nokPhone = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _name.text = user.customerName;
      _email.text = user.email;
      _phone.text = user.phone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _nok.dispose();
    _nokPhone.dispose();
    super.dispose();
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_nokPhone.text.trim().isNotEmpty &&
        Validators.phone(_nokPhone.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Validators.phone(_nokPhone.text) ?? 'Invalid phone'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Lux.error,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    context.read<BookingProvider>().savePassenger(
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          nextOfKin: _nok.text.trim().isEmpty ? null : _nok.text.trim(),
          nextOfKinPhone:
              _nokPhone.text.trim().isEmpty ? null : _nokPhone.text.trim(),
        );
    Navigator.of(context).pushNamed(AppConstants.routePayment);
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final trip = booking.selectedTrip;
    final user = context.watch<AuthProvider>().user;
    final isPhone = Breakpoints.isPhone(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Passenger details')),
      body: Column(
        children: [
          const BookingSteps(current: 1),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  // ── Traveller identity ────────────────────────────
                  Center(
                    child: _AvatarBlock(
                      initial: (user?.customerName.isNotEmpty ?? false)
                          ? user!.customerName[0].toUpperCase()
                          : '?',
                      name: _name.text.isEmpty ? 'Traveller' : _name.text,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (trip != null) _TripSummaryCard(booking: booking),
                  const SizedBox(height: 20),
                  _SectionLabel('Lead passenger'),
                  const SizedBox(height: 12),
                  PremiumTextField(
                    controller: _name,
                    label: 'Full name',
                    hint: 'As it appears on your ticket',
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.required(v, 'Name'),
                  ),
                  const SizedBox(height: 14),
                  PremiumTextField(
                    controller: _email,
                    label: 'Email address',
                    hint: 'Your ticket is sent here',
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 14),
                  PremiumTextField(
                    controller: _phone,
                    label: 'Phone number',
                    hint: '0803 000 0000',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 26),
                  _SectionLabel('Next of kin'),
                  const SizedBox(height: 4),
                  Text(
                    'Optional — used only in an emergency.',
                    style: Lux.caption(context, size: 12),
                  ),
                  const SizedBox(height: 12),
                  PremiumTextField(
                    controller: _nok,
                    label: 'Contact name',
                    hint: 'Emergency contact',
                    prefixIcon: Icons.family_restroom_rounded,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  PremiumTextField(
                    controller: _nokPhone,
                    label: 'Contact phone',
                    hint: 'Emergency contact number',
                    prefixIcon: Icons.contact_phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _continue(),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Lux.darkCard
              : Lux.cardLight,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: ContentShell(
              maxWidth: isPhone ? 720 : 860,
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: Lux.caption(context, size: 11.5)),
                      Text(
                        Formatters.currency(booking.totalPrice,
                            withDecimals: false),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Lux.goldBright
                              : Lux.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: PremiumButton(
                      label: 'Continue to payment',
                      icon: Icons.lock_rounded,
                      onPressed: _continue,
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
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Lux.caption(context, size: 10).copyWith(
        letterSpacing: 1.8,
        fontWeight: FontWeight.w700,
        color: Lux.goldDeep,
      ),
    );
  }
}

/// Decorative avatar with a camera affordance.
///
/// No upload endpoint exists yet, so the badge reports that honestly
/// rather than pretending to attach a file.
class _AvatarBlock extends StatelessWidget {
  final String initial;
  final String name;

  const _AvatarBlock({required this.initial, required this.name});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: Lux.goldGradient,
                border: Border.all(
                  color: isDark ? Lux.darkCard : Lux.cardLight,
                  width: 3,
                ),
                boxShadow: Lux.goldGlow,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Lux.ink,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: isDark ? Lux.darkSurface : Lux.cardLight,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Photo upload is coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Lux.hairlineDark : Lux.hairlineLight,
                      ),
                    ),
                    child: Icon(Icons.photo_camera_outlined,
                        size: 15,
                        color: isDark ? Lux.textOnDark : Lux.ink),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(name, style: Lux.headline(context, size: 20)),
        const SizedBox(height: 3),
        Text('Lead passenger', style: Lux.caption(context, size: 12)),
      ],
    );
  }
}

/// Compact itinerary + seats + fare summary.
class _TripSummaryCard extends StatelessWidget {
  final BookingProvider booking;

  const _TripSummaryCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final trip = booking.selectedTrip!;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Itinerary'),
          const SizedBox(height: 12),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 13, color: Lux.caption(context).color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${Formatters.date(trip.departureDate)} • '
                  '${Formatters.time(trip.departureTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lux.caption(context, size: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SEATS', style: Lux.caption(context, size: 10)),
                    const SizedBox(height: 3),
                    Text(
                      booking.selectedSeats.isEmpty
                          ? '—'
                          : booking.selectedSeats.join(', '),
                      style: Lux.title(context, size: 14.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('FARE', style: Lux.caption(context, size: 10)),
                  const SizedBox(height: 3),
                  Text(
                    Formatters.currency(booking.totalPrice,
                        withDecimals: false),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Lux.goldDeep,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
