import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:futa/main.dart';

void main() {
  testWidgets('FutaApp login screen render test', (WidgetTester tester) async {
    // Build our app under ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: FutaApp(),
      ),
    );

    // Verify that the login screen header text is displayed.
    expect(find.text('Bienvenue sur FUTA'), findsOneWidget);
  });
}
