// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/fhir_repository.dart';

/// Exception thrown when the AI rules engine detects life-threatening conditions.
class EmergencyFlagException implements Exception {
  final double confidence;
  EmergencyFlagException(this.confidence);

  @override
  String toString() =>
      'EMERGENCY FLAG TRIGGERED: Life-threatening condition detected';
}

/// Service handling local AI inference via Google LiteRT-LM (Gemma 4 E2B).
class AiEngineService {
  static const MethodChannel _channel = MethodChannel('com.telemed_k/litert_lm');

  // Static so the flag is shared across the instance created in main() (for
  // initialization) and the instance created by aiEngineServiceProvider (for
  // inference). Both operate on the same native Engine singleton.
  static bool _isInitialized = false;

  // Returned whenever the model is not loaded — keeps the app functional
  // without a crash and avoids an empty state for the user.
  static const Map<String, dynamic> _fallbackResponse = {
    'response':
        'The medical assistant is not available. Please describe your '
        'symptoms and the doctor will follow up with you.',
    'emergency': false,
    'confidence': 0.0,
    'priority': 'normal',
    'ready_to_finalize': false,
    'category': 'other',
  };

  final FhirRepository _fhirRepository;

  // ── Instance state ─────────────────────────────────────────────────────────

  /// Active UI language — set by [setLanguage].
  String _lang = 'en';

  /// True when a doctor has joined the video call — assistant enters silent
  /// documentation mode (records messages, does not respond to patient).
  bool _doctorPresent = false;

  /// Session isolation: full FHIR history is injected only once per session.
  bool _historyInjectedThisSession = false;

  AiEngineService(this._fhirRepository);

  // ── Public controls ────────────────────────────────────────────────────────

  /// Switches the response language. Persists for the lifetime of this instance.
  Future<void> setLanguage(String lang) async {
    _lang = lang;
    try {
      await _channel.invokeMethod<void>('setLanguage', {'lang': lang});
      debugPrint('AiEngineService: language set to $lang');
    } on PlatformException catch (e) {
      debugPrint('AiEngineService.setLanguage error: ${e.code}');
    }
  }

  /// Called when a doctor joins / leaves a VideoConsultationScreen.
  /// In doctor-present mode the assistant silently records messages only.
  void setDoctorPresent(bool present) => _doctorPresent = present;

  /// Resets session-isolation state so the next inference injects full
  /// FHIR history again. Call from [MedicalSessionNotifier.reset] and
  /// [MedicalResponseScreen.initState].
  void resetSession() => _historyInjectedThisSession = false;

  // ── System prompt ──────────────────────────────────────────────────────────

  /// Builds the structured system prompt used by all three evaluate methods.
  ///
  /// [doctorPresent] → silent documentation mode (records only, no reply).
  static String buildSystemPrompt(String lang, bool doctorPresent) {
    if (doctorPresent) {
      return lang == 'en'
          ? 'Silently record all patient messages for the medical report. Do not respond to the patient.'
          : 'Înregistrați silențios toate mesajele pacientului pentru raportul medical. Nu răspundeți pacientului.';
    }

    final isEn = lang == 'en';
    final boundary = isEn
        ? 'Your doctor will address that in the consultation.'
        : 'Medicul dumneavoastră va răspunde la această întrebare în cadrul consultației.';
    final emergency112 = isEn ? 'Call 112 immediately.' : 'Sunați 112 imediat.';
    final greeting   = isEn
        ? 'Hello [name]. What brings you to the doctor today?'
        : 'Bună ziua, [name]. Cu ce vă putem ajuta astăzi?';
    final finalTurn  = isEn
        ? 'Thank you. I have recorded your symptoms. If you have anything to add, please write it now. When ready, press Finalize Dialog.'
        : 'Mulțumesc. Am înregistrat simptomele. Dacă mai aveți ceva de adăugat, scrieți acum. Când sunteți gata, apăsați Finalizează Dialog.';
    final langRule   = isEn
        ? 'Respond EXCLUSIVELY in English regardless of the language the patient uses.'
        : 'Răspundeți EXCLUSIV în română indiferent de limba pe care o folosește pacientul.';
    final toneRule   = isEn
        ? 'Warm, calm. Max 15 words per sentence. Address patient by first name after Turn 1.'
        : 'Ton cald, calm. Maximum 15 cuvinte per propoziție. Folosiți "dumneavoastră" pe tot parcursul.';

    // Few-shot examples
    final ex1q  = isEn ? 'I have a headache.' : 'Am dureri de cap.';
    final ex1r  = isEn ? 'I\'m sorry to hear that. How long have you had this headache?' : 'Îmi pare rău să aud. De cât timp aveți aceste dureri de cap?';
    final ex2q  = isEn ? 'I have chest pain and cannot breathe.' : 'Am dureri în piept și nu pot respira.';
    final ex3q  = isEn ? 'What medication should I take?' : 'Ce medicamente să iau?';
    final ex3r  = isEn
        ? 'Your doctor will address that in the consultation. Can you tell me more about your current symptoms?'
        : 'Medicul dumneavoastră va răspunde la această întrebare. Puteți să îmi spuneți mai multe despre simptomele dumneavoastră?';

    return '''
ROLE: You are a symptom documentation tool for Cabinet Medical Dr. Bogheanu (rural Romania). Help patients describe symptoms clearly so the doctor has a comprehensive report before the consultation.

STRICT BOUNDARIES:
- Ask follow-up questions ONLY. Never diagnose.
- Never recommend medication or treatment.
- Never interpret test results.
- Off-topic medical advice → reply ONLY: "$boundary"
- EMERGENCY EXCEPTION: chest pain + shortness of breath, loss of consciousness, severe bleeding, stroke signs → reply ONLY "$emergency112" and set emergency:true.

CONVERSATION STRUCTURE:
Turn 1: "$greeting"
Turns 2-6: ONE clarifying question per turn — duration / intensity (1-10) / associated symptoms / context / relevant history.
Final turn (when sufficient information collected): "$finalTurn" — set ready_to_finalize:true.

LANGUAGE: $langRule
TONE: $toneRule

MANDATORY JSON FORMAT — every response MUST be valid JSON, no markdown fences:
{"response":"message text","priority":"normal"|"urgent"|"emergency","emergency":false|true,"confidence":0.0-1.0,"ready_to_finalize":false|true,"category":"medical"|"document"|"other"}

EXAMPLES:
Patient: "$ex1q"
{"response":"$ex1r","priority":"normal","emergency":false,"confidence":0.8,"ready_to_finalize":false,"category":"medical"}

Patient: "$ex2q"
{"response":"$emergency112","priority":"emergency","emergency":true,"confidence":0.99,"ready_to_finalize":false,"category":"medical"}

Patient: "$ex3q"
{"response":"$ex3r","priority":"normal","emergency":false,"confidence":0.9,"ready_to_finalize":false,"category":"medical"}
''';
  }

  // ── Response helpers ───────────────────────────────────────────────────────

  static String _cleanText(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'```json', caseSensitive: false), '');
    s = s.replaceAll('```', '');
    s = s.trim();

    if (s.startsWith('{')) {
      try {
        final inner = jsonDecode(s) as Map<String, dynamic>;
        for (final k in ['response', 'recommendation', 'message', 'text']) {
          final val = inner[k];
          if (val is String && val.trim().isNotEmpty) return val.trim();
        }
        return '';
      } catch (_) {}
    }
    return s;
  }

  static Map<String, dynamic> _parseAndNormalize(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'```json', caseSensitive: false), '');
    s = s.replaceAll('```', '');
    s = s.trim();

    final int start = s.indexOf('{');
    final int end   = s.lastIndexOf('}');
    if (start != -1 && end > start) {
      try {
        final parsed = jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
        final out = Map<String, dynamic>.from(parsed);

        String? text;
        for (final k in ['response', 'recommendation']) {
          final val = parsed[k];
          if (val is String && val.trim().isNotEmpty) {
            text = _cleanText(val);
            if (text.isNotEmpty) break;
          }
        }
        out['response'] = (text != null && text.isNotEmpty)
            ? text
            : 'Response received.';

        const validCats = {'medical', 'document', 'other'};
        final aiCat = parsed['category'] as String?;
        if (aiCat != null && validCats.contains(aiCat)) {
          out['category'] = aiCat;
        }
        return out;
      } catch (_) {}
    }

    final prose = _cleanText(s);
    return Map<String, dynamic>.from(_fallbackResponse)
      ..['response'] = prose.isNotEmpty ? prose : _fallbackResponse['response'] as String;
  }

  // ── Streaming shim ─────────────────────────────────────────────────────────

  /// Dart-side streaming shim: splits [fullText] into word chunks of 3,
  /// emitting each with a 40 ms delay to produce a typewriter effect.
  ///
  /// TODO: replace with native EventChannel streaming when available.
  static Stream<String> streamWords(String fullText) async* {
    final words = fullText.split(' ').where((w) => w.isNotEmpty).toList();
    final buffer = StringBuffer();
    for (int i = 0; i < words.length; i += 3) {
      final end = (i + 3).clamp(0, words.length);
      buffer.write(words.sublist(i, end).join(' '));
      if (end < words.length) buffer.write(' ');
      yield buffer.toString();
      await Future.delayed(const Duration(milliseconds: 40));
    }
  }

  // ── History context ────────────────────────────────────────────────────────

  Future<String> _buildHistoryContext(String? customPrompt) async {
    final buffer = StringBuffer();

    // New structured system prompt (Step 1).
    buffer.writeln(buildSystemPrompt(_lang, _doctorPresent));

    if (customPrompt != null && customPrompt.isNotEmpty) {
      buffer.writeln(customPrompt);
    }

    // Session isolation (Step 3): inject full FHIR history only once.
    if (!_historyInjectedThisSession) {
      final history = await _fhirRepository.getPatientHistory();
      if (history.isNotEmpty) {
        buffer.writeln('\nPATIENT MEDICAL HISTORY (FHIR):');
        for (final resource in history) {
          buffer.writeln('- ${resource['resourceType']}: ${jsonEncode(resource)}');
        }
      }
      _historyInjectedThisSession = true;
    } else {
      buffer.writeln('\nPatient history loaded. Current session only.');
    }

    buffer.writeln(
        '\nCLASSIFY: Add "category" to your JSON — "medical" for health/'
        'symptoms, "document" for prescriptions/referrals/certificates, '
        '"other" for admin/scheduling/doctor messages.');

    return buffer.toString();
  }

  // ── Model lifecycle ────────────────────────────────────────────────────────

  static const String _modelFileName = 'gemma-4-E2B-it.litertlm';
  static const String _sdcardPath = '/sdcard/Download/$_modelFileName';

  static Future<String?> _getModelPath() async {
    try {
      final String? nativePath =
          await _channel.invokeMethod<String>('getModelPath');

      if (nativePath != null && nativePath != _sdcardPath) {
        if (File(nativePath).existsSync()) return nativePath;
      }

      final sdcard = File(_sdcardPath);
      if (sdcard.existsSync()) {
        try {
          sdcard.openSync().closeSync();
          return _sdcardPath;
        } catch (e) {
          debugPrint('AiEngineService: sdcard not readable: $e');
        }
      }

      return null;
    } on PlatformException catch (e) {
      debugPrint('AiEngineService._getModelPath error: ${e.code}');
      return null;
    }
  }

  static Future<bool> isModelOnDisk() async => (await _getModelPath()) != null;

  static Future<void> deleteModelFile() async {
    try {
      final String? path = await _getModelPath();
      if (path != null) {
        final f = File(path);
        if (f.existsSync()) {
          f.deleteSync();
          _isInitialized = false;
          debugPrint('AiEngineService: model file deleted at $path');
        }
      }
    } catch (e) {
      debugPrint('AiEngineService.deleteModelFile error: $e');
    }
  }

  Future<bool> initializeModel() async {
    try {
      final String? modelPath = await _getModelPath();
      if (modelPath == null) {
        debugPrint('LiteRT-LM: could not determine model path');
        return false;
      }

      if (!File(modelPath).existsSync()) {
        debugPrint('LiteRT-LM: model not yet downloaded');
        return false;
      }

      await _channel.invokeMethod<void>('loadModel', {'modelPath': modelPath});
      _isInitialized = true;
      debugPrint('LiteRT-LM: engine initialized — $modelPath');
      return true;
    } on PlatformException catch (e) {
      debugPrint('AiEngineService.initializeModel PlatformException: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('AiEngineService.initializeModel error: $e');
      return false;
    }
  }

  // ── Inference ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> evaluateAudio(
    File audioFile, {
    String? customPrompt,
  }) async {
    if (!_isInitialized) return Map<String, dynamic>.from(_fallbackResponse);

    try {
      final String systemPrompt = await _buildHistoryContext(customPrompt);

      final String? jsonResponse =
          await _channel.invokeMethod<String>('evaluateAudio', {
        'audioPath': audioFile.path,
        'systemPrompt': systemPrompt,
        'constraintFormat': 'json',
      });

      if (jsonResponse == null || jsonResponse.isEmpty) {
        return Map<String, dynamic>.from(_fallbackResponse);
      }

      final result = _parseAndNormalize(jsonResponse);
      if (result['emergency'] == true) {
        final double confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
        if (confidence > 0.8) throw EmergencyFlagException(confidence);
      }
      return result;
    } on PlatformException catch (e) {
      debugPrint('AiEngineService.evaluateAudio PlatformException: ${e.code}');
      return Map<String, dynamic>.from(_fallbackResponse);
    } catch (e) {
      debugPrint('AiEngineService.evaluateAudio error: $e');
      return Map<String, dynamic>.from(_fallbackResponse);
    }
  }

  Future<Map<String, dynamic>> evaluateMedia(
    File mediaFile, {
    String? customPrompt,
  }) async {
    if (!_isInitialized) return Map<String, dynamic>.from(_fallbackResponse);

    try {
      final String systemPrompt = await _buildHistoryContext(customPrompt);

      final String? jsonResponse =
          await _channel.invokeMethod<String>('evaluateMedia', {
        'mediaPath': mediaFile.path,
        'systemPrompt': systemPrompt,
        'constraintFormat': 'json',
        'maxDurationSeconds': 60,
      });

      if (jsonResponse == null || jsonResponse.isEmpty) {
        return Map<String, dynamic>.from(_fallbackResponse);
      }

      final result = _parseAndNormalize(jsonResponse);
      if (result['emergency'] == true) {
        final double confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
        if (confidence > 0.8) throw EmergencyFlagException(confidence);
      }
      return result;
    } on PlatformException catch (e) {
      debugPrint('AiEngineService.evaluateMedia PlatformException: ${e.code}');
      return Map<String, dynamic>.from(_fallbackResponse);
    } catch (e) {
      debugPrint('AiEngineService.evaluateMedia error: $e');
      return Map<String, dynamic>.from(_fallbackResponse);
    }
  }

  Future<Map<String, dynamic>> evaluateText(
    String text, {
    String? customPrompt,
  }) async {
    if (!_isInitialized) return Map<String, dynamic>.from(_fallbackResponse);

    try {
      final String systemPrompt = await _buildHistoryContext(customPrompt);

      final String? jsonResponse =
          await _channel.invokeMethod<String>('runInference', {
        'text': text,
        'systemPrompt': systemPrompt,
      });

      if (jsonResponse == null || jsonResponse.isEmpty) {
        return Map<String, dynamic>.from(_fallbackResponse);
      }

      final result = _parseAndNormalize(jsonResponse);
      if (result['emergency'] == true) {
        final double confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
        if (confidence > 0.8) throw EmergencyFlagException(confidence);
      }
      return result;
    } on PlatformException catch (e) {
      debugPrint('AiEngineService.evaluateText PlatformException: ${e.code}');
      return Map<String, dynamic>.from(_fallbackResponse);
    } catch (e) {
      debugPrint('AiEngineService.evaluateText error: $e');
      return Map<String, dynamic>.from(_fallbackResponse);
    }
  }
}
