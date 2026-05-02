// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Phase 7.9 – Automated Quality Assurance
// Widget tests for HomeScreen – touch target and accessibility verification

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telemed_k/core/providers/medical_session_provider.dart';
import 'package:telemed_k/core/services/ai_engine_service.dart';
import 'package:telemed_k/data/repositories/fhir_repository.dart';
import 'package:telemed_k/ui/screens/home_screen.dart';
import 'package:telemed_k/ui/theme/theme.dart';

// ---------------------------------------------------------------------------
// Minimal fakes to allow the widget to render without MethodChannel calls.
// ---------------------------------------------------------------------------
class _FakeFhirRepository extends FhirRepository {
  @override
  Future<void> saveObservation(Map<String, dynamic> o) async {}
  @override
  Future<void> saveCondition(Map<String, dynamic> c) async {}
  @override
  Future<List<Map<String, dynamic>>> getPatientHistory({String cnp = ''}) async => [];
}

class _FakeAiEngineService extends AiEngineService {
  _FakeAiEngineService() : super(_FakeFhirRepository());
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimum touch target enforced by our GEMINI.md accessibility rules.
const double kMinTouchDp = 64.0;

/// Pumps the HomeScreen inside a minimal Material app with Riverpod overrides.
Future<void> _pumpHomeScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fhirRepositoryProvider.overrideWithValue(_FakeFhirRepository()),
        aiEngineServiceProvider.overrideWithValue(_FakeAiEngineService()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ===========================================================================
// TEST SUITE
// ===========================================================================
void main() {
  group('HomeScreen – Touch Target Compliance (≥ 64x64 dp)', () {
    testWidgets('Microphone AccessibleTouchTarget meets 64x64 dp minimum', (tester) async {
      await _pumpHomeScreen(tester);

      // Find the AccessibleTouchTarget wrapping the mic icon
      final micTargets = find.byWidgetPredicate(
        (w) => w is AccessibleTouchTarget && w.semanticLabel == 'Apasă pentru a vorbi cu asistentul',
      );
      expect(micTargets, findsOneWidget);

      final size = tester.getSize(micTargets);
      expect(size.width, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Mic button width must be ≥ $kMinTouchDp dp');
      expect(size.height, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Mic button height must be ≥ $kMinTouchDp dp');
    });

    testWidgets('Camera AccessibleTouchTarget meets 64x64 dp minimum', (tester) async {
      await _pumpHomeScreen(tester);

      final cameraTarget = find.byWidgetPredicate(
        (w) => w is AccessibleTouchTarget && w.semanticLabel == 'Deschide Camera',
      );
      expect(cameraTarget, findsOneWidget);

      final size = tester.getSize(cameraTarget);
      expect(size.width, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Camera button width must be ≥ $kMinTouchDp dp');
      expect(size.height, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Camera button height must be ≥ $kMinTouchDp dp');
    });

    testWidgets('Language toggle AccessibleTouchTarget meets 64x64 dp minimum', (tester) async {
      await _pumpHomeScreen(tester);

      final langTarget = find.byWidgetPredicate(
        (w) => w is AccessibleTouchTarget && w.semanticLabel == 'Schimbă Limba / Change Language',
      );
      expect(langTarget, findsOneWidget);

      final size = tester.getSize(langTarget);
      expect(size.width, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Language toggle width must be ≥ $kMinTouchDp dp');
      expect(size.height, greaterThanOrEqualTo(kMinTouchDp),
          reason: 'Language toggle height must be ≥ $kMinTouchDp dp');
    });
  });

  group('HomeScreen – Semantic Labels for Accessibility', () {
    testWidgets('Microphone button has correct semantic label', (tester) async {
      await _pumpHomeScreen(tester);

      final semantics = find.bySemanticsLabel('Apasă pentru a vorbi cu asistentul');
      expect(semantics, findsOneWidget,
          reason: 'TalkBack/VoiceOver must announce the mic button purpose');
    });

    testWidgets('Camera button has correct semantic label', (tester) async {
      await _pumpHomeScreen(tester);

      final semantics = find.bySemanticsLabel('Deschide Camera');
      expect(semantics, findsOneWidget,
          reason: 'TalkBack/VoiceOver must announce the camera button purpose');
    });

    testWidgets('Language toggle has correct semantic label', (tester) async {
      await _pumpHomeScreen(tester);

      // find.bySemanticsLabel interprets '/' as RegExp, so we use byWidgetPredicate.
      final langTarget = find.byWidgetPredicate(
        (w) => w is AccessibleTouchTarget && w.semanticLabel == 'Schimbă Limba / Change Language',
      );
      expect(langTarget, findsOneWidget,
          reason: 'TalkBack/VoiceOver must announce the language toggle');
    });
  });

  group('HomeScreen – Core UI Layout', () {
    testWidgets('Displays app title "TeleMed_K" in AppBar', (tester) async {
      await _pumpHomeScreen(tester);
      expect(find.text('TeleMed_K'), findsOneWidget);
    });

    testWidgets('Displays instruction text "Apasă și vorbește"', (tester) async {
      await _pumpHomeScreen(tester);
      expect(find.text('Apasă și vorbește'), findsOneWidget);
    });

    testWidgets('Bottom navigation shows exactly 3 items', (tester) async {
      await _pumpHomeScreen(tester);

      expect(find.text('Acasă'), findsOneWidget);
      expect(find.text('Istoric'), findsOneWidget);
      expect(find.text('Doctorul Meu'), findsOneWidget);
    });
  });
}
