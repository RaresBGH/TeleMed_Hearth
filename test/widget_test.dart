// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telemed_k/main.dart';

void main() {
  testWidgets('App starts cleanly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: TeleMedApp()));
    expect(find.text('TeleMed_K'), findsOneWidget);
  });
}
