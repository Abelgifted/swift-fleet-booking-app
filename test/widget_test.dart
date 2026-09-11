import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fleet_booking/main.dart';
import 'package:fleet_booking/utils/constants.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});
    await tester.pumpWidget(const FleetBookingApp());
    await tester.pump(); // first frame
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(AppConstants.appName), findsOneWidget);

    // Let splash's 2.2s bootstrap timer + navigation complete.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
