// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Phase 7.9 – Automated Quality Assurance
// Unit tests for MedicalSessionNotifier & AppNavigationNotifier

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telemed_k/core/providers/app_navigation_provider.dart';
import 'package:telemed_k/core/providers/medical_session_provider.dart';
import 'package:telemed_k/core/services/ai_engine_service.dart';
import 'package:telemed_k/data/repositories/fhir_repository.dart';

// ---------------------------------------------------------------------------
// Manual Fakes – avoids build_runner codegen while keeping tests hermetic.
// ---------------------------------------------------------------------------

/// Fake AiEngineService whose [evaluateAudio] and [evaluateMedia] can be
/// pre-programmed to return a specific JSON payload or throw.
class FakeAiEngineService extends AiEngineService {
  FakeAiEngineService() : super(FakeFhirRepository());

  Map<String, dynamic>? stubResult;
  Exception? stubException;

  @override
  Future<Map<String, dynamic>> evaluateAudio(File audioFile, {String? customPrompt}) async {
    if (stubException != null) throw stubException!;
    return stubResult ?? {};
  }

  @override
  Future<Map<String, dynamic>> evaluateMedia(File mediaFile, {String? customPrompt}) async {
    if (stubException != null) throw stubException!;
    return stubResult ?? {};
  }
}

/// Fake FhirRepository that stores calls in memory without hitting MethodChannels.
class FakeFhirRepository extends FhirRepository {
  final List<Map<String, dynamic>> savedObservations = [];
  final List<Map<String, dynamic>> savedConditions = [];

  @override
  Future<void> saveObservation(Map<String, dynamic> observationJson) async {
    savedObservations.add(observationJson);
  }

  @override
  Future<void> saveCondition(Map<String, dynamic> conditionJson) async {
    savedConditions.add(conditionJson);
  }

  @override
  Future<List<Map<String, dynamic>>> getPatientHistory({String cnp = ''}) async => [];
}

// ---------------------------------------------------------------------------
// Helper: creates a ProviderContainer wired with our fakes.
// ---------------------------------------------------------------------------
({ProviderContainer container, FakeAiEngineService aiEngine, FakeFhirRepository fhirRepo}) _createTestContainer() {
  final fakeRepo = FakeFhirRepository();
  final fakeAi = FakeAiEngineService();

  final container = ProviderContainer(
    overrides: [
      fhirRepositoryProvider.overrideWithValue(fakeRepo),
      aiEngineServiceProvider.overrideWithValue(fakeAi),
    ],
  );

  return (container: container, aiEngine: fakeAi, fhirRepo: fakeRepo);
}

// ===========================================================================
// TEST SUITE
// ===========================================================================
void main() {
  // ── MedicalSessionNotifier ──────────────────────────────────────────────
  group('MedicalSessionNotifier', () {
    test('initial state is idle', () {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      expect(env.container.read(medicalSessionProvider), SessionState.idle);
    });

    test('startRecording transitions state to recording', () {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      env.container.read(medicalSessionProvider.notifier).startRecording();
      expect(env.container.read(medicalSessionProvider), SessionState.recording);
    });

    // ── Emergency path (processAudio) ───────────────────────────────────
    test('processAudio transitions to emergency when AI returns emergency JSON', () async {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      // Simulate the AI engine throwing EmergencyFlagException,
      // which is what happens when the JSON payload {"emergency": true, "confidence": 0.95} is parsed.
      env.aiEngine.stubException = EmergencyFlagException(0.95);

      await env.container
          .read(medicalSessionProvider.notifier)
          .processAudio(File('fake_emergency_audio.wav'));

      expect(env.container.read(medicalSessionProvider), SessionState.emergency);
    });

    test('processAudio transitions to success for benign result with observation', () async {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      env.aiEngine.stubResult = {
        'observation': {
          'resourceType': 'Observation',
          'code': {'text': 'Blood Pressure'},
          'valueQuantity': {'value': 120, 'unit': 'mmHg'},
        },
      };

      await env.container
          .read(medicalSessionProvider.notifier)
          .processAudio(File('fake_audio.wav'));

      expect(env.container.read(medicalSessionProvider), SessionState.success);
      // Verify the FHIR observation was persisted
      expect(env.fhirRepo.savedObservations, hasLength(1));
      expect(env.fhirRepo.savedObservations.first['resourceType'], 'Observation');
    });

    test('processAudio transitions to error on generic exception', () async {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      env.aiEngine.stubException = Exception('Network timeout');

      await env.container
          .read(medicalSessionProvider.notifier)
          .processAudio(File('fail.wav'));

      expect(env.container.read(medicalSessionProvider), SessionState.error);
      expect(
        env.container.read(medicalSessionProvider).errorMessage,
        contains('Network timeout'),
      );
    });

    // ── Emergency path (processMedia) ───────────────────────────────────
    test('processMedia transitions to emergency when AI returns emergency JSON', () async {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      env.aiEngine.stubException = EmergencyFlagException(0.92);

      await env.container
          .read(medicalSessionProvider.notifier)
          .processMedia(File('fake_emergency_photo.jpg'));

      expect(env.container.read(medicalSessionProvider), SessionState.emergency);
    });

    test('processMedia transitions to success for benign result with condition', () async {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      env.aiEngine.stubResult = {
        'condition': {
          'resourceType': 'Condition',
          'code': {'text': 'Mild Rash'},
        },
      };

      await env.container
          .read(medicalSessionProvider.notifier)
          .processMedia(File('rash_photo.jpg'));

      expect(env.container.read(medicalSessionProvider), SessionState.success);
      expect(env.fhirRepo.savedConditions, hasLength(1));
    });

    // ── Reset ────────────────────────────────────────────────────────────
    test('reset returns state to idle and clears errorMessage', () async {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      env.aiEngine.stubException = Exception('fail');
      await env.container
          .read(medicalSessionProvider.notifier)
          .processAudio(File('x.wav'));
      expect(env.container.read(medicalSessionProvider), SessionState.error);

      env.container.read(medicalSessionProvider.notifier).reset();
      expect(env.container.read(medicalSessionProvider), SessionState.idle);
      expect(env.container.read(medicalSessionProvider).errorMessage, isNull);
    });
  });

  // ── AppNavigationNotifier ───────────────────────────────────────────────
  group('AppNavigationNotifier', () {
    test('initial route is home', () {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      // Force initialization of the navigation provider
      expect(env.container.read(appNavigationProvider), AppRoute.home);
    });

    test('emergency routing override: session emergency triggers AppRoute.emergency', () async {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      // Initialize appNavigationProvider so it starts listening to medicalSessionProvider
      final initialRoute = env.container.read(appNavigationProvider);
      expect(initialRoute, AppRoute.home);

      // Trigger an emergency via the medical session
      env.aiEngine.stubException = EmergencyFlagException(0.95);
      await env.container
          .read(medicalSessionProvider.notifier)
          .processAudio(File('emergency.wav'));

      // The listener inside AppNavigationNotifier.build() should have fired
      expect(env.container.read(appNavigationProvider), AppRoute.emergency);
    });

    test('success routing: session success triggers AppRoute.medicalResponse', () async {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      env.container.read(appNavigationProvider); // Initialize listener

      env.aiEngine.stubResult = {
        'observation': {
          'resourceType': 'Observation',
          'code': {'text': 'Heart Rate'},
        },
      };

      await env.container
          .read(medicalSessionProvider.notifier)
          .processAudio(File('heartbeat.wav'));

      expect(env.container.read(appNavigationProvider), AppRoute.medicalResponse);
    });

    test('reset routing: session idle triggers AppRoute.home', () async {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      env.container.read(appNavigationProvider); // Initialize listener

      // First go to success
      env.aiEngine.stubResult = {'observation': {'resourceType': 'Observation'}};
      await env.container
          .read(medicalSessionProvider.notifier)
          .processAudio(File('x.wav'));
      expect(env.container.read(appNavigationProvider), AppRoute.medicalResponse);

      // Then reset
      env.container.read(medicalSessionProvider.notifier).reset();
      expect(env.container.read(appNavigationProvider), AppRoute.home);
    });

    test('navigateTo overrides route manually', () {
      final env = _createTestContainer();
      addTearDown(env.container.dispose);

      env.container.read(appNavigationProvider.notifier).navigateTo(AppRoute.history);
      expect(env.container.read(appNavigationProvider), AppRoute.history);
    });
  });
}
