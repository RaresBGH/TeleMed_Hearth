// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/practitioner_constants.dart';
import '../l10n/app_strings.dart';
import '../models/chat_message.dart';
import '../services/ai_engine_service.dart';
import '../services/audio_recording_service.dart';
import '../utils/date_formatter.dart';
import '../utils/fhir_extension_utils.dart';
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
  /// FHIR Practitioner reference for the doctor in this session.
  /// Written to Observation as 'reviewed-by-target' extension on finalize.
  final String? lastPractitionerRef;
  /// Session category tag extracted from AI response (BUG 7 fix).
  /// Values: "medical" | "document" | "other"
  /// TODO(extend): expand category taxonomy as usage patterns emerge.
  final String? lastSessionCategory;
  /// Language active when the last AI response was received ('en' or 'ro').
  /// Used by finalizeConsultation to localise FHIR observation labels.
  final String? lastSessionLanguage;
  /// The patient's most recent input text (or '[Voice message]' / '[Photo]').
  /// Used by MedicalResponseScreen to seed the patient bubble on entry.
  final String? lastPatientMessage;
  /// File path of the patient's home-screen voice recording (WAV).
  /// Passed to MedicalResponseScreen so the seeded voice bubble has an
  /// attachmentPath for the audio player.
  final String? lastAudioPath;
  /// File path of the patient's home-screen photo capture (JPEG).
  /// Passed to MedicalResponseScreen so the seeded image bubble has an
  /// attachmentPath for the thumbnail viewer.
  final String? lastImagePath;

  const MedicalSessionState({
    required this.sessionState,
    this.lastAiResponse,
    this.lastIsEmergency = false,
    this.lastResumeMessages,
    this.lastResumeObservationId,
    this.errorMessage,
    this.lastDoctorName,
    this.lastPractitionerRef,
    this.lastSessionCategory,
    this.lastSessionLanguage,
    this.lastPatientMessage,
    this.lastAudioPath,
    this.lastImagePath,
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
      await _handleResult(result, patientMessage: '[Voice message]', patientAudioPath: audioFile.path);
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
      await _handleResult(result, patientMessage: '[Photo]', patientAudioPath: null, patientImagePath: mediaFile.path);
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
      await _handleResult(result, patientMessage: text, patientAudioPath: null);
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
  Future<void> finalizeConsultation(
    List<ChatMessage> messages, {
    String? lastAiText,
    String? aiCategory,
  }) async {
    // Guard: prevent duplicate FHIR writes if called more than once per session.
    if (_finalized) return;
    _finalized = true;
    debugPrint('finalizeConsultation: _finalized=$_finalized, messages=${messages.length}');
    try {
      final String cnp           = ref.read(loginCnpProvider);
      final String timestamp     = DateTime.now().toIso8601String();
      final String triageResponse = lastAiText ?? state.lastAiResponse ?? 'Triaj AI';
      // Resolve Medplum Patient ID so the Observation subject uses a direct
      // Patient/{id} reference. Medplum does not match identifier-based subjects
      // when querying by subject=Patient/{id}, causing new entries to be invisible.
      String? medplumPatientId;
      if (cnp.isNotEmpty) {
        try {
          final patient = await _fhirRepository.getPatientByCnp(cnp);
          medplumPatientId = patient?['id'] as String?;
        } catch (_) {}
      }

      final String sessionLang = state.lastSessionLanguage ?? 'ro';
      final String prefixAi      = AppStrings.of(sessionLang, 'chat.prefix_ai');
      final String prefixPatient = AppStrings.of(sessionLang, 'chat.prefix_patient');

      final StringBuffer noteBuffer = StringBuffer();
      for (final msg in messages) {
        final String prefix = msg.role == 'ai' ? '[$prefixAi]' : '[$prefixPatient]';
        final String timeStr =
            DateFormatter.formatTimeOfDay(msg.timestamp.hour, msg.timestamp.minute);
        // Use clean localized labels for audio/photo in the FHIR note.
        // The Doctor UI reads note[0].text verbatim; embedding file paths
        // would expose internal Android storage paths. Replay from the Dossier
        // uses msg.text (already a clean placeholder) with no attachmentPath.
        final String content;
        if (msg.attachmentType == AttachmentType.audio) {
          content = AppStrings.of(sessionLang, 'chat.attachment_voice_label');
        } else if (msg.attachmentType == AttachmentType.image) {
          content = AppStrings.of(sessionLang, 'chat.attachment_photo_label');
        } else {
          content = msg.text;
        }
        noteBuffer.writeln('$prefix $timeStr: $content');
      }

      // Append the clinical summary as the final [AI] line so the Doctor UI's
      // last-[AI]-line extraction reads the summary, not the last conversation turn.
      // The Doctor UI reads note[0].text → filters lines starting with [AI] →
      // takes the last one as the clinical summary display.
      if (lastAiText != null && lastAiText!.isNotEmpty) {
        final summaryTime = DateFormatter.formatTimeOfDay(
            DateTime.now().hour, DateTime.now().minute);
        noteBuffer.writeln('[$prefixAi] $summaryTime: $lastAiText');
      }

      // Resolve doctorName and category for attribution and classification.
      // aiCategory (from last inference result) takes priority over session state.
      final String? doctorName = state.lastDoctorName;
      final String category = state.lastIsEmergency
          ? 'medical'
          : (aiCategory ?? state.lastSessionCategory ?? 'medical');

      final extensions = <Map<String, dynamic>>[
        {
          'url': FhirExtensionUtils.sessionCategoryUrl,
          'valueString': category,
        },
        if (doctorName != null && doctorName.isNotEmpty)
          {
            'url': FhirExtensionUtils.doctorNameUrl,
            'valueString': doctorName,
          },
        {
          'url': FhirExtensionUtils.reviewedByTargetUrl,
          'valueString': state.lastPractitionerRef ?? Practitioners.familyDoctorId,
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
        'subject': medplumPatientId != null
            ? {'reference': 'Patient/$medplumPatientId'}
            : {
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
      try { ref.invalidate(patientHistoryProvider); } catch (_) {}
      debugPrint('finalizeConsultation: FHIR write complete');
    } catch (e) {
      debugPrint('finalizeConsultation: FHIR write FAILED: $e');
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

  /// Replaces lastAudioPath with the AAC path once transcoding completes.
  /// Called from home_screen after processAudio() returns and before the
  /// WAV is deleted, so the voice bubble points to the permanent AAC file.
  void updateAudioPath(String? aacPath) {
    if (aacPath == null) return;
    state = MedicalSessionState(
      sessionState: state.sessionState,
      lastAiResponse: state.lastAiResponse,
      lastIsEmergency: state.lastIsEmergency,
      lastResumeMessages: state.lastResumeMessages,
      lastResumeObservationId: state.lastResumeObservationId,
      errorMessage: state.errorMessage,
      lastDoctorName: state.lastDoctorName,
      lastPractitionerRef: state.lastPractitionerRef,
      lastSessionCategory: state.lastSessionCategory,
      lastSessionLanguage: state.lastSessionLanguage,
      lastPatientMessage: state.lastPatientMessage,
      lastAudioPath: aacPath,
      lastImagePath: state.lastImagePath,
    );
  }

  /// Replaces lastImagePath with a permanent copy path after the home-screen
  /// photo triage, so the image bubble survives after the temp file is deleted.
  void updateImagePath(String? imagePath) {
    if (imagePath == null) return;
    state = MedicalSessionState(
      sessionState: state.sessionState,
      lastAiResponse: state.lastAiResponse,
      lastIsEmergency: state.lastIsEmergency,
      lastResumeMessages: state.lastResumeMessages,
      lastResumeObservationId: state.lastResumeObservationId,
      errorMessage: state.errorMessage,
      lastDoctorName: state.lastDoctorName,
      lastPractitionerRef: state.lastPractitionerRef,
      lastSessionCategory: state.lastSessionCategory,
      lastSessionLanguage: state.lastSessionLanguage,
      lastPatientMessage: state.lastPatientMessage,
      lastAudioPath: state.lastAudioPath,
      lastImagePath: imagePath,
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
      lastPractitionerRef: state.lastPractitionerRef,
      lastSessionCategory: state.lastSessionCategory,
      lastAudioPath: state.lastAudioPath,
      lastImagePath: state.lastImagePath,
    );
  }

  /// Sets doctor context for a "Trimite mesaj" session without pre-seeding any
  /// patient message. The chat opens clean; lastDoctorName is preserved so
  /// finalizeConsultation can attribute the entry to the correct doctor.
  void setDoctorContext(String doctorName, {String? practitionerRef}) {
    state = MedicalSessionState(
      sessionState: SessionState.idle,
      lastDoctorName: doctorName,
      lastPractitionerRef: practitionerRef,
      lastSessionCategory: 'other',
    );
  }

  /// Clears lastPatientMessage from state after it has been injected into the
  /// chat screen, preventing double-injection on re-entry.
  void clearPatientMessage() {
    state = MedicalSessionState(
      sessionState: state.sessionState,
      lastAiResponse: state.lastAiResponse,
      lastIsEmergency: state.lastIsEmergency,
      lastDoctorName: state.lastDoctorName,
      lastPractitionerRef: state.lastPractitionerRef,
      lastSessionCategory: state.lastSessionCategory,
      lastSessionLanguage: state.lastSessionLanguage,
      lastAudioPath: state.lastAudioPath,
      lastImagePath: state.lastImagePath,
      // lastPatientMessage intentionally omitted → null
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
      lastPractitionerRef: state.lastPractitionerRef,
    );
  }

  Future<void> reset() async {
    _finalized = false; // FIRST: reset guard before any cleanup that could throw
    await ref.read(audioRecordingServiceProvider).stopAndRelease();
    // Reset session isolation so next session injects fresh FHIR history.
    ref.read(aiEngineServiceProvider).resetSession();
    state = MedicalSessionState.idle;
  }

  Future<void> _handleResult(Map<String, dynamic> result,
      {required String patientMessage, String? patientAudioPath, String? patientImagePath}) async {
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
      lastPractitionerRef: state.lastPractitionerRef,
      lastSessionCategory: category,
      lastSessionLanguage: _lang,
      lastPatientMessage: patientMessage,
      lastAudioPath: patientAudioPath,
      lastImagePath: patientImagePath,
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
