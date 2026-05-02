// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/ai_engine_service.dart';
import '../services/audio_recording_service.dart';
import '../../data/repositories/fhir_repository.dart';
import 'auth_provider.dart';

enum SessionState { idle, recording, processing, success, emergency, error }

// ── Immutable state ───────────────────────────────────────────────────────────

class MedicalSessionState {
  final SessionState sessionState;
  final String? lastAiResponse;
  final bool lastIsEmergency;
  final List<ChatMessage>? lastResumeMessages;
  final String? lastResumeObservationId;
  final String? errorMessage;

  const MedicalSessionState({
    required this.sessionState,
    this.lastAiResponse,
    this.lastIsEmergency = false,
    this.lastResumeMessages,
    this.lastResumeObservationId,
    this.errorMessage,
  });

  static const idle = MedicalSessionState(sessionState: SessionState.idle);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MedicalSessionNotifier extends Notifier<MedicalSessionState> {
  @override
  MedicalSessionState build() => MedicalSessionState.idle;

  AiEngineService get _aiEngineService => ref.read(aiEngineServiceProvider);
  FhirRepository  get _fhirRepository  => ref.read(fhirRepositoryProvider);

  void startRecording() {
    state = const MedicalSessionState(sessionState: SessionState.recording);
  }

  Future<void> processAudio(File audioFile) async {
    state = const MedicalSessionState(sessionState: SessionState.processing);
    try {
      final result = await _aiEngineService.evaluateAudio(audioFile);
      await _handleResult(result);
    } on EmergencyFlagException catch (_) {
      state = const MedicalSessionState(sessionState: SessionState.emergency);
    } catch (e) {
      state = MedicalSessionState(
        sessionState: SessionState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> processMedia(File mediaFile) async {
    state = const MedicalSessionState(sessionState: SessionState.processing);
    try {
      final result = await _aiEngineService.evaluateMedia(mediaFile);
      await _handleResult(result);
    } on EmergencyFlagException catch (_) {
      state = const MedicalSessionState(sessionState: SessionState.emergency);
    } catch (e) {
      state = MedicalSessionState(
        sessionState: SessionState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> processText(String text) async {
    state = const MedicalSessionState(sessionState: SessionState.processing);
    try {
      final result = await _aiEngineService.evaluateText(text);
      await _handleResult(result);
    } on EmergencyFlagException catch (_) {
      state = const MedicalSessionState(sessionState: SessionState.emergency);
    } catch (e) {
      state = MedicalSessionState(
        sessionState: SessionState.error,
        errorMessage: e.toString(),
      );
    }
  }

  // TODO: PRODUCTION: status changes to final only after doctor approval via
  // doctor-side app. Auto-save is intentionally disabled — patient must
  // explicitly finalize.
  Future<void> finalizeConsultation(List<ChatMessage> messages) async {
    final String cnp           = ref.read(loginCnpProvider);
    final String timestamp     = DateTime.now().toIso8601String();
    final String triageResponse = state.lastAiResponse ?? 'Triaj AI';

    final StringBuffer noteBuffer = StringBuffer();
    for (final msg in messages) {
      final String prefix = msg.role == 'ai' ? '[AI]' : '[Pacient]';
      final String timeStr =
          '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
          '${msg.timestamp.minute.toString().padLeft(2, '0')}';
      noteBuffer.writeln('$prefix $timeStr: ${msg.text}');
    }

    final observationPayload = {
      'resourceType': 'Observation',
      'status': 'preliminary',
      'code': {
        'coding': [
          {
            'system': 'http://loinc.org',
            'code': '75325-1',
            'display': 'Symptom',
          }
        ],
        'text': 'Dialog Triaj AI',
      },
      'subject': {
        'identifier': {
          'system': 'urn:oid:1.2.40.0.10.1.4.3.1',
          'value': cnp.isNotEmpty ? cnp : 'unknown',
        }
      },
      'effectiveDateTime': timestamp,
      'valueString': triageResponse,
      'note': [
        {'text': noteBuffer.toString()}
      ],
    };

    final existingId = state.lastResumeObservationId;
    if (existingId != null && existingId.isNotEmpty) {
      await _fhirRepository.updateObservation(existingId, observationPayload);
    } else {
      await _fhirRepository.saveObservation(observationPayload);
    }
  }

  /// Called from Dosar Medical before navigating to medicalResponse route.
  /// [existingObservationId] is the FHIR resource ID of the saved dialog being
  /// resumed. When provided, finalizeConsultation() will update that resource
  /// instead of creating a duplicate entry.
  void prepareResume({
    required String aiResponse,
    required List<ChatMessage> messages,
    String? existingObservationId,
  }) {
    state = MedicalSessionState(
      sessionState: state.sessionState,
      lastAiResponse: aiResponse,
      lastIsEmergency: false,
      lastResumeMessages: messages,
      lastResumeObservationId: existingObservationId,
    );
  }

  Future<void> reset() async {
    await ref.read(audioRecordingServiceProvider).stopAndRelease();
    state = MedicalSessionState.idle;
  }

  Future<void> _handleResult(Map<String, dynamic> result) async {
    final String? response  = result['response'] as String?;
    final bool isEmergency  = result['emergency'] == true;
    if (isEmergency) {
      throw EmergencyFlagException(
        (result['confidence'] as num?)?.toDouble() ?? 0.0,
      );
    }
    state = MedicalSessionState(
      sessionState: SessionState.success,
      lastAiResponse: response,
      lastIsEmergency: false,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final fhirRepositoryProvider = Provider<FhirRepository>((ref) => FhirRepository());

final aiEngineServiceProvider = Provider<AiEngineService>((ref) {
  final fhirRepo = ref.read(fhirRepositoryProvider);
  return AiEngineService(fhirRepo);
});

final medicalSessionProvider =
    NotifierProvider<MedicalSessionNotifier, MedicalSessionState>(() {
  return MedicalSessionNotifier();
});
