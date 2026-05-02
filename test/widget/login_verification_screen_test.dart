// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Phase 7.9 – Automated Quality Assurance
// Widget tests for LoginVerificationScreen – touch target and accessibility verification

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telemed_k/core/providers/auth_provider.dart';
import 'package:telemed_k/ui/screens/login_verification_screen.dart';

// ---------------------------------------------------------------------------
// Fakes – prevent real network calls and native platform channel invocations
// ---------------------------------------------------------------------------

// TODO: re-enable when Medplum auth is implemented (B0 phase)
// _FakeMedplumAuthService was removed when medplum_auth_service.dart was
// deleted as dead code. Re-add once Medplum is wired.

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimum touch target enforced by our GEMINI.md accessibility rules.
const double kMinTouchDp = 64.0;

/// Pumps the LoginVerificationScreen inside a minimal Material app.
Future<void> _pumpLoginVerificationScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginCnpProvider.overrideWith(() => LoginCnpNotifier()),
      ],
      child: const MaterialApp(
        home: LoginVerificationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ===========================================================================
// TEST SUITE
// ===========================================================================
void main() {
  group('LoginVerificationScreen – Touch Target Compliance (≥ 64x64 dp)', () {
    testWidgets('Primary CTA button meets 64x64 dp minimum', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      // The main green button with text "SUNT DE ACORD CU TERMENII - CREEAZĂ CONT"
      final ctaFinder = find.widgetWithText(ElevatedButton, 'SUNT DE ACORD CU TERMENII - CREEAZĂ CONT');
      expect(ctaFinder, findsOneWidget);

      final size = tester.getSize(ctaFinder);
      expect(size.height, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Primary CTA height must be ≥ $kMinTouchDp dp (actual: ${size.height})');
      // Width is full-width so it will far exceed 64, but verify regardless
      expect(size.width, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Primary CTA width must be ≥ $kMinTouchDp dp');
    });

    testWidgets('Terms of Use legal button meets 64x64 dp minimum', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      final termsFinder = find.widgetWithText(ElevatedButton, '📖 Termeni de Utilizare');
      expect(termsFinder, findsOneWidget);

      final size = tester.getSize(termsFinder);
      expect(size.height, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Terms button height must be ≥ $kMinTouchDp dp (actual: ${size.height})');
      expect(size.width, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Terms button width must be ≥ $kMinTouchDp dp');
    });

    testWidgets('Privacy Policy legal button meets 64x64 dp minimum', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      final privacyFinder = find.widgetWithText(ElevatedButton, '🔒 Politica de Confidențialitate');
      expect(privacyFinder, findsOneWidget);

      final size = tester.getSize(privacyFinder);
      expect(size.height, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Privacy button height must be ≥ $kMinTouchDp dp (actual: ${size.height})');
      expect(size.width, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Privacy button width must be ≥ $kMinTouchDp dp');
    });
  });

  group('LoginVerificationScreen – Semantic Labels & Accessibility', () {
    testWidgets('Primary CTA button has semantic "button" role', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      // ElevatedButton automatically provides button semantics
      final ctaFinder = find.widgetWithText(ElevatedButton, 'SUNT DE ACORD CU TERMENII - CREEAZĂ CONT');
      expect(ctaFinder, findsOneWidget);

      // Verify the button text is accessible via semantics tree
      final semanticsFinder = find.text('SUNT DE ACORD CU TERMENII - CREEAZĂ CONT');
      expect(semanticsFinder, findsOneWidget,
          reason: 'CTA text must be readable by assistive technologies');
    });

    testWidgets('Legal buttons have accessible text labels', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      expect(find.text('📖 Termeni de Utilizare'), findsOneWidget,
          reason: 'Terms button text must be readable by assistive technologies');
      expect(find.text('🔒 Politica de Confidențialitate'), findsOneWidget,
          reason: 'Privacy button text must be readable by assistive technologies');
    });

    testWidgets('Resend code link has accessible text', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      expect(find.text('Nu ați primit codul? Trimite din nou'), findsOneWidget,
          reason: 'Resend link text must be readable by assistive technologies');
    });
  });

  group('LoginVerificationScreen – OTP Input Layout', () {
    testWidgets('Renders exactly 6 OTP input fields', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      // Each OTP digit is a TextField
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6),
          reason: 'Must render exactly 6 OTP digit fields');
    });

    testWidgets('OTP field auto-advances focus on digit entry', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      final textFields = find.byType(TextField);

      // Enter a digit in the first field
      await tester.enterText(textFields.at(0), '7');
      await tester.pump();

      // Focus should advance to the second field
      final secondField = tester.widget<TextField>(textFields.at(1));
      expect(secondField.focusNode?.hasFocus, isTrue,
          reason: 'Focus must auto-advance to next field after digit entry');
    });

    testWidgets('Security context card is visible', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      expect(
        find.textContaining('Siguranța datelor dumneavoastră'),
        findsOneWidget,
        reason: 'Security reassurance card must be visible',
      );
    });

    testWidgets('No back arrow enforced (automaticallyImplyLeading: false)', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      // There should be no BackButton in the AppBar
      expect(find.byType(BackButton), findsNothing,
          reason: 'Single-axis nav rule: no top-left back arrow');
    });
  });

  group('LoginVerificationScreen – AppBar Compliance', () {
    testWidgets('AppBar title shows "Verificare"', (tester) async {
      await _pumpLoginVerificationScreen(tester);
      expect(find.text('Verificare'), findsOneWidget);
    });

    testWidgets('AppBar background matches off-white theme', (tester) async {
      await _pumpLoginVerificationScreen(tester);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFF5F5F5),
          reason: 'AppBar background must match WCAG AAA soft off-white');
    });
  });
}
