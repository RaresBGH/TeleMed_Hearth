// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/ai_engine_service.dart';
import '../../data/repositories/fhir_repository.dart';
import 'auth_provider.dart';

enum SessionState { idle, recording, processing, success, emergency, error }

class MedicalSessionNotifier extends Notifier<SessionState> {
  String? errorMessage;

  /// The `response` text returned by the AI — displayed on MedicalResponseScreen.
  String? lastAiResponse;

  /// Always false in the success path (emergency=true throws before reaching success).
  /// Carried as a field so MedicalResponseScreen can read it from the notifier.
  bool lastIsEmergency = false;

  @override
  SessionState build() => SessionState.idle;

  AiEngineService get _aiEngineService => ref.read(aiEngineServiceProvider);
  FhirRepository  get _fhirRepository  => ref.read(fhirRepositoryProvider);

  void startRecording() {
    state = SessionState.recording;
    errorMessage = null;
  }

  Future<void> processAudio(File audioFile) async {
    state = SessionState.processing;
    try {
      final result = await _aiEngineService.evaluateAudio(audioFile);
      await _handleResult(result);
    } on EmergencyFlagException catch (_) {
      state = SessionState.emergency;
    } catch (e) {
      errorMessage = e.toString();
      state = SessionState.error;
    }
  }

  Future<void> processMedia(File mediaFile) async {
    state = SessionState.processing;
    try {
      final result = await _aiEngineService.evaluateMedia(mediaFile);
      await _handleResult(result);
    } on EmergencyFlagException catch (_) {
      state = SessionState.emergency;
    } catch (e) {
      errorMessage = e.toString();
      state = SessionState.error;
    }
  }

  Future<void> processText(String text) async {
    state = SessionState.processing;
    try {
      final result = await _aiEngineService.evaluateText(text);
      await _handleResult(result);
    } on EmergencyFlagException catch (_) {
      state = SessionState.emergency;
    } catch (e) {
      errorMessage = e.toString();
      state = SessionState.error;
    }
  }

  // TODO: PRODUCTION: status changes to final only after doctor approval via
  // doctor-side app. Auto-save is intentionally disabled — patient must
  // explicitly finalize.
  Future<void> finalizeConsultation(List<ChatMessage> messages) async {
    final String cnp = ref.read(loginCnpProvider);
    final String timestamp = DateTime.now().toIso8601String();
    final String triageResponse = lastAiResponse ?? 'Triaj AI';

    final StringBuffer noteBuffer = StringBuffer();
    for (final msg in messages) {
      final String prefix = msg.role == 'ai' ? '[AI]' : '[Pacient]';
      final String timeStr =
          '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
          '${msg.timestamp.minute.toString().padLeft(2, '0')}';
      noteBuffer.writeln('$prefix $timeStr: ${msg.text}');
    }

    await _fhirRepository.saveObservation({
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
    });
  }

  void reset() {
    state = SessionState.idle;
    errorMessage   = null;
    lastAiResponse  = null;
    lastIsEmergency = false;
  }

  // ── Result parser ─────────────────────────────────────────────────────────
  //
  // AI schema: { response, emergency, confidence, doctor_summary }
  //
  // • response       — text shown to the patient on ConfirmationScreen
  // • emergency      — bool; triggers EmergencyFlagException when true
  //                    (AiEngineService already throws for confidence > 0.8;
  //                     this catches any emergency=true that slipped through)
  // • confidence     — float 0–1, forwarded to EmergencyFlagException
  // • doctor_summary — stored as FHIR Observation text for the doctor
  Future<void> _handleResult(Map<String, dynamic> result) async {
    lastAiResponse = result['response'] as String?;

    final bool isEmergency = result['emergency'] == true;
    if (isEmergency) {
      throw EmergencyFlagException(
        (result['confidence'] as num?)?.toDouble() ?? 0.0,
      );
    }

    // Persist triage output as a FHIR Observation so it appears in history
    // and is included in future AI context injections.
    final String? doctorSummary = result['doctor_summary'] as String?;
    final String observationText =
        doctorSummary ?? lastAiResponse ?? 'Triaj AI';

    await _fhirRepository.saveObservation({
      'resourceType': 'Observation',
      'status': 'final',
      'code': {
        'coding': [
          {
            'system': 'http://loinc.org',
            'code': '75325-1',
            'display': 'Symptom',
          }
        ],
        'text': 'Triaj AI',
      },
      'valueString': observationText,
      'effectiveDateTime': DateTime.now().toIso8601String(),
    });

    state = SessionState.success;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final fhirRepositoryProvider = Provider<FhirRepository>((ref) => FhirRepository());

final aiEngineServiceProvider = Provider<AiEngineService>((ref) {
  final fhirRepo = ref.read(fhirRepositoryProvider);
  return AiEngineService(fhirRepo);
});

final medicalSessionProvider =
    NotifierProvider<MedicalSessionNotifier, SessionState>(() {
  return MedicalSessionNotifier();
});
