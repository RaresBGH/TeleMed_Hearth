// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

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

  /// Last initialization error string for diagnostic display. Null when init
  /// succeeded or has not been attempted. Cleared at the start of each
  /// initializeModel() call.
  static String? lastInitError;

  /// ValueNotifier updated on every initializeModel() attempt — widgets can
  /// listen for immediate reactivity without depending on an outer provider rebuild.
  static final ValueNotifier<String?> initErrorNotifier =
      ValueNotifier<String?>(null);

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
  void resetSession() {
    _historyInjectedThisSession = false;
    _doctorPresent = false;
  }

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

    // EN triage prompt — patient-first, 30-word cap, full parity with RO on
    // emergency/suicide/markdown/schema clauses.
    if (lang == 'en') {
      return '''You are a medical AI assistant for patient triage in a Romanian rural clinic. The patient speaks first — never greet or open the conversation. Wait for the patient\'s input, then respond with empathy and ask ONE focused follow-up question. Maximum 30 words per sentence. Always respond in English. Never suggest diagnoses, medications, or doses. Ask a maximum of 5 focused follow-up questions per complaint. If the patient describes symptoms that would benefit from visual assessment (skin conditions, rashes, swelling, wounds, visible injuries) AND has not already sent a photo in this conversation, ask them to share a photo. Say: \'I can help better if you share a photo. Please use the camera button below to take one.\' If a photo has already been shared in this conversation, analyze it directly without asking again. After the 5th question, provide a brief 1-sentence clinical summary of what the patient described, then say: \'If this covers everything, please tap the Finalize Dialog button. You can still add more information if needed.\' After this point, do not ask new questions. If the patient adds more information, acknowledge it briefly and repeat: \'When you are ready, please tap Finalize Dialog.\' Set ready_to_finalize: true after delivering the summary prompt and keep it true for all subsequent responses. For life-threatening emergencies (cardiac pain with dyspnea, stroke signs, severe hemorrhage, loss of consciousness, anaphylaxis), respond only with \'Call 112 immediately.\' and set emergency=true. For suicidal ideation, respond with an empathic message including the Suicide Prevention Line 0800 801 200. Do not use markdown formatting — emit raw JSON, no ```json or ``` blocks. For each response, emit EXACTLY one JSON object with these fields: response (text in English addressed to the patient), emergency (boolean), confidence (0.0 or 0.9), priority ("normal", "urgent", or "emergency"), ready_to_finalize (boolean — true after the summary and for all subsequent responses), category (one of: "duration", "intensity", "associated_symptoms", "context", "history", "close", "emergency", "greeting", "other", "medical", "document").''';
    }
    // Romanian triage assistant prompt — matches fine-tuned adapter training schema.
    // Patient speaks first; AI responds with confirmation + one clarifying question.
    // Sentence cap ≤30 words; no AI greeting; patient-first conversation enforced here.
    return 'Ești un asistent medical AI pentru triajul pacienților vârstnici din mediul rural românesc. '
        'Pacientul descrie simptomele; tu pui întrebări clarificatoare scurte și politicoase, una singură pe rând, '
        'până ai suficiente informații pentru medicul de familie. '
        'Niciodată nu sugerezi diagnostice, medicamente sau doze. '
        'Dacă pacientul descrie simptome care ar beneficia de evaluare vizuală (afecțiuni ale pielii, erupții, umflături, răni, leziuni vizibile) '
        'ȘI nu a trimis deja o fotografie în această conversație, '
        'cere-i să facă o fotografie folosind butonul de cameră de mai jos. '
        'Spune: \'Pot ajuta mai bine dacă îmi arați o fotografie. Vă rugăm folosiți butonul de cameră de mai jos.\' '
        'Dacă o fotografie a fost deja trimisă în această conversație, analizează-o direct fără a mai cere alta. '
        'Pentru fiecare răspuns, emiteți EXACT un obiect JSON cu aceste câmpuri: '
        'response (textul în română adresat pacientului), '
        'emergency (boolean), '
        'confidence (0.0 sau 0.9), '
        'priority ("normal", "urgent" sau "emergency"), '
        'ready_to_finalize (boolean — true după rezumat și pentru toate răspunsurile ulterioare), '
        'category ("duration", "intensity", "associated_symptoms", "context", "history", "close" sau "emergency"). '
        'Pentru urgențe vitale (durere precordială cu dispnee, semne AVC, hemoragie severă, pierdere de conștiență, anafilaxie), '
        'răspundeți doar cu "Sunați 112 imediat." și setați emergency=true. '
        'Pentru ideație suicidară, răspundeți cu mesajul empatic incluzând Telefonul Antisuicid 0800 801 200. '
        'Nu folosiți formatare markdown — emiteți JSON brut, fără ```json sau ``` blocuri. '
        'Pune maximum 5 întrebări de urmărire per acuză. '
        'După a 5-a întrebare, oferă un rezumat clinic scurt de o propoziție, '
        'apoi spune: \'Dacă aceasta acoperă tot, te rog apasă butonul Finalizează Dialogul. Poți adăuga informații suplimentare dacă este necesar.\' '
        'După acest punct, nu mai pune întrebări noi. '
        'Dacă pacientul adaugă informații, confirmă scurt și repetă: \'Când ești gata, te rog apasă Finalizează Dialogul.\' '
        'Setează ready_to_finalize: true după livrarea rezumatului și menține-l true pentru toate răspunsurile ulterioare.';
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

    // Strip markdown code-fence wrappers emitted by some model checkpoints.
    // Handles both ```json\n...\n``` and ```\n...\n``` forms.
    if (s.startsWith('```')) {
      final nl = s.indexOf('\n');
      if (nl != -1) s = s.substring(nl + 1); // drop opening fence line
      final close = s.lastIndexOf('```');
      if (close != -1) s = s.substring(0, close); // drop closing fence
      s = s.trim();
    } else {
      // Legacy: remove stray fence markers scattered in mixed output.
      s = s.replaceAll(RegExp(r'```json', caseSensitive: false), '');
      s = s.replaceAll('```', '');
      s = s.trim();
    }

    // Filter the empty-list artifact emitted by LiteRT-LM on some turns.
    if (s == '[]' || s == '[ ]') {
      return Map<String, dynamic>.from(_fallbackResponse);
    }

    // Attempt 1: direct JSON parse on the fully cleaned string.
    try {
      final parsed = jsonDecode(s) as Map<String, dynamic>;
      return _applyFieldNorms(parsed);
    } catch (_) {}

    // Attempt 2: extract the outermost {...} substring (handles leading prose).
    final int start = s.indexOf('{');
    final int end   = s.lastIndexOf('}');
    if (start != -1 && end > start) {
      try {
        final parsed = jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
        return _applyFieldNorms(parsed);
      } catch (_) {}
    }

    // Total failure: return fallback with any extractable prose text.
    final prose = _cleanText(s);
    return Map<String, dynamic>.from(_fallbackResponse)
      ..['response'] = prose.isNotEmpty ? prose : _fallbackResponse['response'] as String;
  }

  /// Normalises field values from a successfully parsed JSON map.
  static Map<String, dynamic> _applyFieldNorms(Map<String, dynamic> parsed) {
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

    // Accept training-schema categories and legacy values; coerce unknown → 'other'.
    const validCats = {
      'duration', 'intensity', 'associated_symptoms', 'context',
      'history', 'close', 'emergency', 'greeting', 'other',
      'medical', 'document',
    };
    final aiCat = parsed['category'] as String?;
    if (aiCat != null && !validCats.contains(aiCat)) {
      out['category'] = 'other';
    }
    return out;
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

  // ── Prompt construction ────────────────────────────────────────────────────

  /// Returns the role/rules/format system prompt ONLY — no conversation
  /// history, no FHIR data, no patient messages.
  /// Passed as systemInstruction to the LiteRT-LM ConversationConfig.
  String buildSystemPromptOnly(String lang, bool doctorPresent) {
    return buildSystemPrompt(lang, doctorPresent);
  }

  /// Returns the conversation history + FHIR data block — everything that
  /// was in _buildHistoryContext() EXCEPT the system prompt line.
  /// Injected into the user turn alongside the patient's actual input.
  Future<String> buildConversationContext(String? customPrompt) async {
    final buffer = StringBuffer();

    if (customPrompt != null && customPrompt.isNotEmpty) {
      buffer.writeln(customPrompt);
    }

    // Session isolation: inject full FHIR history only once per session.
    if (!_historyInjectedThisSession) {
      final history = await _fhirRepository.getPatientHistory();
      if (history.isNotEmpty) {
        buffer.writeln('\nPATIENT MEDICAL HISTORY (FHIR):');
        final conditions = history.where((r) => r['resourceType'] == 'Condition').toList();
        final observations = history.where((r) => r['resourceType'] == 'Observation').toList();
        // Limit to last 3 Observations to reduce context size and improve response speed.
        final recentObs = observations.length > 3
            ? observations.sublist(observations.length - 3)
            : observations;
        for (final resource in [...conditions, ...recentObs]) {
          buffer.writeln('- ${resource['resourceType']}: ${jsonEncode(resource)}');
        }
      }
      _historyInjectedThisSession = true;
    } else {
      buffer.writeln('\nPatient history loaded. Current session only.');
    }

    return buffer.toString();
  }

  // ── Model lifecycle ────────────────────────────────────────────────────────

  static const String _modelFileName = 'gemma-4-E4B-it.litertlm';
  static const String _sdcardPath = '/sdcard/Download/$_modelFileName';

  static Future<String?> _getModelPath() async {
    try {
      final String? nativePath =
          await _channel.invokeMethod<String>('getModelPath');

      if (nativePath != null && nativePath != _sdcardPath) {
        try {
          if (File(nativePath).existsSync()) return nativePath;
        } catch (e) {
          debugPrint('Model path check error: $e');
          return null;
        }
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
    lastInitError = null;
    initErrorNotifier.value = null; // clear before each attempt
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
      lastInitError = '${e.code}: ${e.message}';
      initErrorNotifier.value = lastInitError;
      debugPrint('AiEngineService.initializeModel PlatformException: ${e.code}');
      return false;
    } catch (e) {
      lastInitError = e.toString();
      initErrorNotifier.value = lastInitError;
      debugPrint('AiEngineService.initializeModel error: $e');
      return false;
    }
  }

  // ── Diagnostic log ────────────────────────────────────────────────────────

  /// Appends a single JSONL line to the on-device debug log (Part C / Fix #11).
  /// Fire-and-forget; failure is silently swallowed.
  Future<void> appendDebugLog(String line) async {
    try {
      await _channel.invokeMethod<void>('appendDebugLog', {'line': line});
    } catch (_) {}
  }

  /// Reads back the last [maxBytes] of the on-device debug log.
  /// Returns null if the file does not exist or on any error.
  Future<String?> readDebugLog({int maxBytes = 50000}) async {
    try {
      return await _channel.invokeMethod<String>('readDebugLog', {'maxBytes': maxBytes});
    } catch (_) {
      return null;
    }
  }

  // ── Inference ──────────────────────────────────────────────────────────────

  /// Queries the Kotlin engine state via MethodChannel to detect Dart/Kotlin
  /// state divergence (e.g. engine crashed mid-session while _isInitialized
  /// is still true on the Dart side).
  Future<bool> _isKotlinEngineReady() async {
    try {
      final ready = await _channel.invokeMethod<bool>('isEngineReady');
      return ready ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> evaluateAudio(
    File audioFile, {
    String? customPrompt,
  }) async {
    if (!_isInitialized) {
      debugPrint('AiEngineService: _isInitialized was false on entry — attempting re-init');
      try {
        final reInit = await initializeModel();
        if (!reInit) return Map<String, dynamic>.from(_fallbackResponse);
      } catch (e) {
        debugPrint('AiEngineService.evaluateAudio re-init threw: $e');
        return Map<String, dynamic>.from(_fallbackResponse);
      }
    }

    final kotlinReady = await _isKotlinEngineReady();
    if (!kotlinReady) {
      debugPrint('AiEngineService: Kotlin engine not ready — attempting re-init');
      _isInitialized = false;
      final reInit = await initializeModel();
      if (!reInit) return Map<String, dynamic>.from(_fallbackResponse);
    }

    try {
      final String sysPrompt = buildSystemPromptOnly(_lang, _doctorPresent);
      final String ctx = await buildConversationContext(customPrompt);
      final String userTurn = ctx.isNotEmpty ? '$ctx\n[Voice message]' : '[Voice message]';

      final String? jsonResponse =
          await _channel.invokeMethod<String>('evaluateAudio', {
        'audioPath': audioFile.path,
        'text': userTurn,
        'systemPrompt': sysPrompt,
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
      _isInitialized = false;
      return Map<String, dynamic>.from(_fallbackResponse);
    } catch (e) {
      debugPrint('AiEngineService.evaluateAudio error: $e');
      _isInitialized = false;
      return Map<String, dynamic>.from(_fallbackResponse);
    }
  }

  Future<Map<String, dynamic>> evaluateMedia(
    File mediaFile, {
    String? customPrompt,
  }) async {
    if (!_isInitialized) {
      debugPrint('AiEngineService: _isInitialized was false on entry — attempting re-init');
      try {
        final reInit = await initializeModel();
        if (!reInit) return Map<String, dynamic>.from(_fallbackResponse);
      } catch (e) {
        debugPrint('AiEngineService.evaluateMedia re-init threw: $e');
        return Map<String, dynamic>.from(_fallbackResponse);
      }
    }

    final kotlinReady = await _isKotlinEngineReady();
    if (!kotlinReady) {
      debugPrint('AiEngineService: Kotlin engine not ready — attempting re-init');
      _isInitialized = false;
      final reInit = await initializeModel();
      if (!reInit) return Map<String, dynamic>.from(_fallbackResponse);
    }

    try {
      final String sysPrompt = buildSystemPromptOnly(_lang, _doctorPresent);
      final String ctx = await buildConversationContext(customPrompt);
      final String userTurn = ctx.isNotEmpty ? '$ctx\n[Photo]' : '[Photo]';

      final String? jsonResponse =
          await _channel.invokeMethod<String>('evaluateMedia', {
        'mediaPath': mediaFile.path,
        'text': userTurn,
        'systemPrompt': sysPrompt,
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
      if (e.code == 'IMAGE_INFERENCE_ERROR') {
        // Image-specific error — engine is still alive, do not reset _isInitialized.
        return {
          ...Map<String, dynamic>.from(_fallbackResponse),
          'response': 'Nu am putut analiza fotografia. Vă rugăm descrieți simptomele prin voce sau text.',
        };
      }
      _isInitialized = false;
      return Map<String, dynamic>.from(_fallbackResponse);
    } catch (e) {
      debugPrint('AiEngineService.evaluateMedia error: $e');
      _isInitialized = false;
      return Map<String, dynamic>.from(_fallbackResponse);
    }
  }

  Future<Map<String, dynamic>> evaluateText(
    String text, {
    String? customPrompt,
  }) async {
    if (!_isInitialized) {
      debugPrint('AiEngineService: _isInitialized was false on entry — attempting re-init');
      try {
        final reInit = await initializeModel();
        if (!reInit) return Map<String, dynamic>.from(_fallbackResponse);
      } catch (e) {
        debugPrint('AiEngineService.evaluateText re-init threw: $e');
        return Map<String, dynamic>.from(_fallbackResponse);
      }
    }

    final kotlinReady = await _isKotlinEngineReady();
    if (!kotlinReady) {
      debugPrint('AiEngineService: Kotlin engine not ready — attempting re-init');
      _isInitialized = false;
      final reInit = await initializeModel();
      if (!reInit) return Map<String, dynamic>.from(_fallbackResponse);
    }

    try {
      final String sysPrompt = buildSystemPromptOnly(_lang, _doctorPresent);
      final String ctx = await buildConversationContext(customPrompt);
      final String userTurn = ctx.isNotEmpty ? '$ctx\n$text' : text;

      final String? jsonResponse =
          await _channel.invokeMethod<String>('runInference', {
        'text': userTurn,
        'systemPrompt': sysPrompt,
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
      _isInitialized = false;
      return Map<String, dynamic>.from(_fallbackResponse);
    } catch (e) {
      debugPrint('AiEngineService.evaluateText error: $e');
      _isInitialized = false;
      return Map<String, dynamic>.from(_fallbackResponse);
    }
  }
}
