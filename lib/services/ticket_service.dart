import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/booking.dart';
import '../models/trip.dart';

/// Generates a printable PDF ticket and shares it via the OS sheet.
class TicketService {
  /// Builds + shares `ticket-<ref>.pdf`. Returns the file path.
  static Future<String> shareTicket({
    required List<Booking> bookings,
    required Trip? trip,
    required double amount,
    required String passengerName,
  }) async {
    final pdf = pw.Document();
    final ref = bookings.isNotEmpty
        ? bookings.first.paymentReference
        : 'N/A';
    final seats = bookings.map((b) => b.seatNumber).join(', ');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF0D47A1),
              ),
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FLEET BOOKING',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight:
                            pw.FontWeight.bold,
                        color: PdfColors.white,
                      )),
                  pw.Text('E-Ticket • $ref',
                      style: const pw.TextStyle(
                          color: PdfColors.white)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            _row('Passenger', passengerName),
            _row('Route',
                trip == null ? '—' : '${trip.source} → ${trip.destination}'),
            _row('Date', trip?.departureDate ?? '—'),
            _row('Time', trip?.departureTime ?? '—'),
            _row('Vehicle',
                trip == null
                    ? '—'
                    : '${trip.assetName} • ${trip.vehicleRegNo}'),
            _row('Seats', seats.isEmpty ? '—' : seats),
            _row('Amount', 'NGN ${amount.toStringAsFixed(0)}'),
            _row('Reference', ref),
            pw.SizedBox(height: 24),
            pw.Text(
              'Show this ticket (or its reference) at boarding. '
              'Arrive 30 minutes before departure.',
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/ticket-${ref.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.pdf');
    await file.writeAsBytes(await pdf.save());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'My Fleet Booking ticket ($ref)',
        subject: 'Fleet Booking E-Ticket',
      ),
    );
    return file.path;
  }

  static pw.Widget _row(String label, String value) => pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700)),
            ),
            pw.Expanded(child: pw.Text(value)),
          ],
        ),
      );
}
