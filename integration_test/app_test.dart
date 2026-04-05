// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telemed_k/main.dart';
import 'package:telemed_k/core/services/ai_engine_service.dart';
import 'package:telemed_k/core/providers/medical_session_provider.dart';
import 'package:telemed_k/ui/theme/theme.dart';
import 'package:telemed_k/ui/screens/emergency_screen.dart';

class MockAiEngineService extends AiEngineService {
  MockAiEngineService(super.fhirRepository);

  @override
  Future<Map<String, dynamic>> evaluateAudio(File audioFile) async {
    // SECURITY LIMITS: Triggering synthetic 112 emergency routing constraints accurately directly without local leaks 
    throw EmergencyFlagException(0.95);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TeleMed_K E2E Accessibility & Logic Verification Suite', () {
    
    testWidgets('UI Verification: Touch targets are strictly >= 64x64 dp & Typography >= 18sp', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: TeleMedApp()));
      await tester.pumpAndSettle();

      // Ensure that we explicitly test the accessibility bounds locally
      final touchTargets = find.byType(AccessibleTouchTarget);
      expect(touchTargets, findsWidgets, reason: 'AccessibleTouchTargets must exist organically in UI mappings');

      for (var i = 0; i < touchTargets.evaluate().length; i++) {
        final target = touchTargets.at(i);
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(64.0), reason: 'Touch target width must be >= 64dp limit');
        expect(size.height, greaterThanOrEqualTo(64.0), reason: 'Touch target height must be >= 64dp limit');
      }

      final bottomNav = find.byType(BottomNavigationBar);
      expect(bottomNav, findsOneWidget);
      final navSize = tester.getSize(bottomNav);
      expect(navSize.height, greaterThanOrEqualTo(64.0), reason: 'Bottom Navigation bar must support >= 64dp active hit targets securely');

      final texts = find.byType(Text);
      for (var i = 0; i < texts.evaluate().length; i++) {
        final textWidget = tester.widget<Text>(texts.at(i));
        final fontSize = textWidget.style?.fontSize;
        if (fontSize != null) {
          expect(fontSize, greaterThanOrEqualTo(18.0), reason: 'Typography body text scale must be strictly mapped at >= 18sp');
        }
      }
    });

    testWidgets('Logic Verification: Extreme bounds invoke exact Emergency 112 intercept mapping', (WidgetTester tester) async {
      final mockModel = ProviderScope(
        overrides: [
          aiEngineServiceProvider.overrideWith((ref) => MockAiEngineService(ref.read(fhirRepositoryProvider))),
        ],
        child: const TeleMedApp(),
      );

      await tester.pumpWidget(mockModel);
      await tester.pumpAndSettle();

      // Emulate finding massive accessible limits targeting primary mic 
      final micInteraction = find.byIcon(Icons.mic);
      expect(micInteraction, findsOneWidget);

      await tester.tap(micInteraction);
      // Simulates the internal delay formatting hooks resolving accurately into navigation state map seamlessly
      await tester.pump(const Duration(seconds: 4)); 
      await tester.pumpAndSettle();

      // Dynamically verify standard limits execute the routing constraints mapping emergency correctly
      expect(find.byType(EmergencyScreen), findsOneWidget, reason: 'Emergency Route Controller must safely direct native targets executing limits automatically.');
    });
  });
}
