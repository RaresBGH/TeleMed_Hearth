// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_engine_service.dart';
import '../../data/repositories/fhir_repository.dart';

enum SessionState { idle, recording, processing, success, emergency, error }

class MedicalSessionNotifier extends Notifier<SessionState> {
  String? errorMessage;

  @override
  SessionState build() => SessionState.idle;

  AiEngineService get _aiEngineService => ref.read(aiEngineServiceProvider);
  FhirRepository get _fhirRepository => ref.read(fhirRepositoryProvider);

  void startRecording() {
    state = SessionState.recording;
    errorMessage = null;
  }

  Future<void> processAudio(File audioFile) async {
    state = SessionState.processing;
    try {
      final result = await _aiEngineService.evaluateAudio(audioFile);
      
      // Save valid FHIR resources mapped from result
      if (result.containsKey('observation')) {
        await _fhirRepository.saveObservation(result['observation'] as Map<String, dynamic>);
      }
      if (result.containsKey('condition')) {
        await _fhirRepository.saveCondition(result['condition'] as Map<String, dynamic>);
      }
      
      state = SessionState.success;
    } on EmergencyFlagException catch (_) {
      state = SessionState.emergency;
    } catch (e) {
      errorMessage = e.toString();
      state = SessionState.error;
    }
  }

  void reset() {
    state = SessionState.idle;
    errorMessage = null;
  }

  Future<void> processMedia(File mediaFile) async {
    state = SessionState.processing;
    try {
      final result = await _aiEngineService.evaluateMedia(mediaFile);
      
      // Save valid FHIR resources mapped from result
      if (result.containsKey('observation')) {
        await _fhirRepository.saveObservation(result['observation'] as Map<String, dynamic>);
      }
      if (result.containsKey('condition')) {
        await _fhirRepository.saveCondition(result['condition'] as Map<String, dynamic>);
      }
      
      state = SessionState.success;
    } on EmergencyFlagException catch (_) {
      state = SessionState.emergency;
    } catch (e) {
      errorMessage = e.toString();
      state = SessionState.error;
    }
  }
}

// Global Providers mapping
final fhirRepositoryProvider = Provider<FhirRepository>((ref) => FhirRepository());

final aiEngineServiceProvider = Provider<AiEngineService>((ref) {
  final fhirRepo = ref.read(fhirRepositoryProvider);
  return AiEngineService(fhirRepo);
});

final medicalSessionProvider = NotifierProvider<MedicalSessionNotifier, SessionState>(() {
  return MedicalSessionNotifier();
});
