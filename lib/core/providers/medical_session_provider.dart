// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../models/chat_message.dart';
import '../services/ai_engine_service.dart';
import '../services/audio_recording_service.dart';
import '../utils/date_formatter.dart';
import '../../data/repositories/fhir_repository.dart';
import 'auth_provider.dart';
import 'medplum_auth_provider.dart';
import 'patient_history_provider.dart';

enum SessionState { idle, recording, processing, success, emergency, error }

// ── Immutable state ───────────────────────────────────────────────────────────

class MedicalSessionState {
  final SessionState sessionState;
  final String? lastAiResponse;
  final bool lastIsEmergency;
  final List<ChatMessage>? lastResumeMessages;
  final String? lastResumeObservationId;
  final String? errorMessage;
  /// Doctor attribution for "Trimite mesaj" sessions (BUG 4 fix).
  final String? lastDoctorName;
  /// Session category tag extracted from AI response (BUG 7 fix).
  /// Values: "medical" | "document" | "other"
  /// TODO(extend): expand category taxonomy as usage patterns emerge.
  final String? lastSessionCategory;
  /// Language active when the last AI response was received ('en' or 'ro').
  /// Used by finalizeConsultation to localise FHIR observation labels.
  final String? lastSessionLanguage;

  const MedicalSessionState({
    required this.sessionState,
    this.lastAiResponse,
    this.lastIsEmergency = false,
    this.lastResumeMessages,
    this.lastResumeObservationId,
    this.errorMessage,
    this.lastDoctorName,
    this.lastSessionCategory,
    this.lastSessionLanguage,
  });

  static const idle = MedicalSessionState(sessionState: SessionState.idle);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MedicalSessionNotifier extends Notifier<MedicalSessionState> {
  @override
  MedicalSessionState build() => MedicalSessionState.idle;

  // Duplicate-entry guard: true after the first successful finalizeConsultation().
  // Reset by reset() so the next session can finalize normally.
  bool _finalized = false;

  /// Active UI language — kept in sync via [setLanguage] so finalizeConsultation
  /// can localise FHIR observation labels without reading a provider.
  String _lang = 'ro';

  /// Called by the language-aware UI layer (e.g. MedicalResponseScreen) whenever
  /// the user switches language so FHIR notes are written in the correct language.
  void setLanguage(String lang) => _lang = lang;

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
    // Guard: prevent duplicate FHIR writes if called more than once per session.
    if (_finalized) return;
    _finalized = true;
    try {
      final String cnp           = ref.read(loginCnpProvider);
      final String timestamp     = DateTime.now().toIso8601String();
      final String triageResponse = state.lastAiResponse ?? 'Triaj AI';

      final String sessionLang = state.lastSessionLanguage ?? 'ro';
      final String prefixAi      = AppStrings.of(sessionLang, 'chat.prefix_ai');
      final String prefixPatient = AppStrings.of(sessionLang, 'chat.prefix_patient');

      final StringBuffer noteBuffer = StringBuffer();
      for (final msg in messages) {
        final String prefix = msg.role == 'ai' ? '[$prefixAi]' : '[$prefixPatient]';
        final String timeStr =
            DateFormatter.formatTimeOfDay(msg.timestamp.hour, msg.timestamp.minute);
        noteBuffer.writeln('$prefix $timeStr: ${msg.text}');
      }

      // Resolve doctorName and category for attribution and classification.
      final String? doctorName = state.lastDoctorName;
      final String category = state.lastIsEmergency
          ? 'medical'
          : (state.lastSessionCategory ?? 'medical');

      final extensions = <Map<String, dynamic>>[
        {
          'url': 'http://telemed-k.example.com/fhir/extension/session-category',
          'valueString': category,
        },
        if (doctorName != null && doctorName.isNotEmpty)
          {
            'url': 'http://telemed-k.example.com/fhir/extension/doctor-name',
            'valueString': doctorName,
          },
      ];

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
          'text': AppStrings.of(state.lastSessionLanguage ?? 'ro', 'chat.section_label'),
        },
        'subject': {
          'identifier': {
            'system': 'urn:oid:1.2.40.0.10.1.4.3.1',
            'value': cnp.isNotEmpty ? cnp : 'unknown',
          }
        },
        'effectiveDateTime': timestamp,
        'valueString': triageResponse,
        'extension': extensions,
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
      // Invalidate AFTER the FHIR write completes so the history screen
      // re-fetches the updated list, not the pre-write snapshot.
      ref.invalidate(patientHistoryProvider);
    } catch (e) {
      throw Exception('Failed to save consultation to local FHIR database: $e');
    }
  }

  /// Called from Dosar Medical before navigating to medicalResponse route.
  /// [existingObservationId] is the FHIR resource ID of the saved dialog being
  /// resumed. When provided, finalizeConsultation() will update that resource
  /// instead of creating a duplicate entry.
  /// Initialises a fresh chat session pre-seeded with a patient message.
  /// Used by "Trimite mesaj" on the doctor profile screen — the preseed
  /// text appears as the patient's first bubble in MedicalResponseScreen.
  ///
  /// TODO(medplum): scope message thread to [practitionerRef] when Medplum wired.
  void startWithPreseed(String message, {String? doctorName}) {
    // Reset all previous session state. lastAiResponse is set to the preseed
    // text so MedicalResponseScreen's triage card shows the conversation
    // context rather than a stale triage result or generic fallback.
    state = MedicalSessionState(
      sessionState: SessionState.idle,
      lastAiResponse: message,
      lastResumeMessages: [
        ChatMessage(
          role: 'patient',
          text: message,
          timestamp: DateTime.now(),
        ),
      ],
      lastDoctorName: doctorName,
      lastSessionCategory: 'other', // default for doctor messages; AI may override
    );
  }

  /// Clears the preseed message from state after it has been injected into
  /// the chat screen. Call via postFrameCallback in MedicalResponseScreen
  /// to prevent double injection on re-entry.
  void clearPreseed() {
    // Clear lastResumeMessages to prevent double-injection on re-entry.
    // Preserve doctorName and category so finalizeConsultation can use them.
    state = MedicalSessionState(
      sessionState: state.sessionState,
      lastAiResponse: state.lastAiResponse,
      lastIsEmergency: state.lastIsEmergency,
      lastDoctorName: state.lastDoctorName,
      lastSessionCategory: state.lastSessionCategory,
    );
  }

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
    // Reset session isolation so next session injects fresh FHIR history.
    ref.read(aiEngineServiceProvider).resetSession();
    _finalized = false; // allow finalization in the next session
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
    // Extract AI-provided category; fall back to current category or 'medical'.
    const _validCategories = {'medical', 'document', 'other'};
    final aiCategory = result['category'] as String?;
    final category = (aiCategory != null && _validCategories.contains(aiCategory))
        ? aiCategory
        : (state.lastSessionCategory ?? 'medical');
    state = MedicalSessionState(
      sessionState: SessionState.success,
      lastAiResponse: response,
      lastIsEmergency: false,
      lastDoctorName: state.lastDoctorName,
      lastSessionCategory: category,
      lastSessionLanguage: _lang,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final fhirRepositoryProvider = Provider<FhirRepository>((ref) {
  return FhirRepository(medplum: ref.watch(medplumRepositoryProvider));
});

final aiEngineServiceProvider = Provider<AiEngineService>((ref) {
  final fhirRepo = ref.read(fhirRepositoryProvider);
  return AiEngineService(fhirRepo);
});

final medicalSessionProvider =
    NotifierProvider<MedicalSessionNotifier, MedicalSessionState>(() {
  return MedicalSessionNotifier();
});
