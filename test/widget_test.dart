import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:depositsystem/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: LSSCONEApp(),
      ),
    );

    // Verify that we are on the login screen.
    expect(find.text('LSSC Global'), findsOneWidget);
    expect(find.text('Access Wallet'), findsOneWidget);
  });
}
