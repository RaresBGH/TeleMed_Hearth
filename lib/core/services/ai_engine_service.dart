// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

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
        'Asistentul AI nu este disponibil momentan. Vă rugăm descrieți '
        'simptomele dumneavoastră și medicul vă va contacta.',
    'emergency': false,
    'confidence': 0.0,
    'doctor_summary': null,
  };

  final FhirRepository _fhirRepository;

  AiEngineService(this._fhirRepository);

  // ──────────────────────────────────────────────────────────────────────────
  // Response normalisation helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Strips markdown fences from [raw] and, if the result is still a JSON
  /// object, extracts the first human-readable text field it contains.
  /// Returns empty string when nothing usable is found — never raw braces.
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
        return ''; // suppress raw JSON braces
      } catch (_) {}
    }
    return s;
  }

  /// Parses [raw] (possibly fenced or prose) into a normalised result map
  /// where 'response' is always clean human-readable text.
  static Map<String, dynamic> _parseAndNormalize(String raw) {
    // Strip markdown fences from the outer wrapper first.
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'```json', caseSensitive: false), '');
    s = s.replaceAll('```', '');
    s = s.trim();

    // Find the outermost JSON object.
    final int start = s.indexOf('{');
    final int end   = s.lastIndexOf('}');
    if (start != -1 && end > start) {
      try {
        final parsed = jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
        final out = Map<String, dynamic>.from(parsed);

        // Normalise the human-readable field.
        String? text;
        for (final k in ['response', 'recommendation']) {
          final val = parsed[k];
          if (val is String && val.trim().isNotEmpty) {
            text = _cleanText(val);
            if (text.isNotEmpty) break;
          }
        }
        if (text == null || text.isEmpty) {
          debugPrint(
              'AiEngineService._parseAndNormalize: FALLBACK — '
              'response/recommendation field absent or empty after _cleanText; '
              'snippet="${s.length > 80 ? s.substring(0, 80) : s}"');
        }
        out['response'] = (text != null && text.isNotEmpty)
            ? text
            : 'Răspuns primit. Medicul va fi contactat.';
        return out;
      } catch (_) {}
    }

    // No JSON found — treat as prose.
    final prose = _cleanText(s);
    return Map<String, dynamic>.from(_fallbackResponse)
      ..['response'] = prose.isNotEmpty
          ? prose
          : _fallbackResponse['response'] as String;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Language
  // ──────────────────────────────────────────────────────────────────────────

  /// Instructs the native LiteRtLmChannel to generate responses in [lang].
  /// [lang] must be "ro" (Romanian) or "en" (English).
  Future<void> setLanguage(String lang) async {
    try {
      await _channel.invokeMethod<void>('setLanguage', {'lang': lang});
      debugPrint('AiEngineService: language set to $lang');
    } on PlatformException catch (e) {
      debugPrint('AiEngineService.setLanguage PlatformException: ${e.code}');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Model lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  static const String _modelFileName = 'gemma-4-E2B-it.litertlm';
  static const String _sdcardPath = '/sdcard/Download/$_modelFileName';

  /// Locates the model file, checking two paths in order:
  ///   1. app-private filesDir/models/ (normal install / download path)
  ///   2. /sdcard/Download/ (sideloaded for testing — used directly, not copied)
  ///
  /// Returns null if absent from both locations.
  static Future<String?> _getModelPath() async {
    try {
      // Check primary path first (app-private storage, set by native layer).
      final String? nativePath =
          await _channel.invokeMethod<String>('getModelPath');

      if (nativePath != null && nativePath != _sdcardPath) {
        if (File(nativePath).existsSync()) return nativePath;
      }

      // Check sdcard path — return directly without copying.
      // Copying fails on Android 13+ (scoped storage) without
      // MANAGE_EXTERNAL_STORAGE, which requires Play Store approval.
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

  /// Returns true if the model file is present on disk (either app-private or
  /// sdcard path). Safe to call from any context; never throws.
  static Future<bool> isModelOnDisk() async => (await _getModelPath()) != null;

  /// Deletes the on-device model file and resets the initialized flag.
  /// Called as part of the account-deletion flow. Never throws.
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

  /// Initializes the LiteRT-LM engine with the locally stored model file.
  ///
  /// Returns true if the engine loaded successfully.
  /// Returns false gracefully if the model file has not been downloaded yet —
  /// logs "LiteRT-LM: model not yet downloaded" and leaves the app functional
  /// (evaluate methods return [_fallbackResponse] instead of crashing).
  ///
  /// Safe to call on startup — never throws.
  Future<bool> initializeModel() async {
    try {
      final String? modelPath = await _getModelPath();
      if (modelPath == null) {
        debugPrint('LiteRT-LM: could not determine model path from native layer');
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

  // ──────────────────────────────────────────────────────────────────────────
  // Inference
  // ──────────────────────────────────────────────────────────────────────────

  /// Builds the system prompt string from [customPrompt] and the patient's
  /// local FHIR history. Called by all three evaluate methods.
  Future<String> _buildHistoryContext(String? customPrompt) async {
    final List<Map<String, dynamic>> patientHistory =
        await _fhirRepository.getPatientHistory();
    final buffer = StringBuffer();
    if (customPrompt != null) buffer.writeln(customPrompt);
    if (patientHistory.isNotEmpty) {
      buffer.writeln('LOCAL PATIENT MEDICAL HISTORY (HL7 FHIR):');
      for (final resource in patientHistory) {
        buffer.writeln('- ${resource['resourceType']}: ${jsonEncode(resource)}');
      }
    }
    return buffer.toString();
  }

  /// Feeds a WAV audio file to the LiteRT-LM engine for triage analysis.
  /// Injects the patient's FHIR history as system-prompt context (local RAG).
  /// Returns [_fallbackResponse] if the model is not yet initialized.
  Future<Map<String, dynamic>> evaluateAudio(
    File audioFile, {
    String? customPrompt,
  }) async {
    if (!_isInitialized) {
      return Map<String, dynamic>.from(_fallbackResponse);
    }

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

      final Map<String, dynamic> result = _parseAndNormalize(jsonResponse);

      if (result['emergency'] == true) {
        final double confidence =
            (result['confidence'] as num?)?.toDouble() ?? 0.0;
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

  /// Evaluates a media file (image or video) via the LiteRT-LM engine.
  /// Returns [_fallbackResponse] if the model is not yet initialized.
  Future<Map<String, dynamic>> evaluateMedia(
    File mediaFile, {
    String? customPrompt,
  }) async {
    if (!_isInitialized) {
      return Map<String, dynamic>.from(_fallbackResponse);
    }

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

      final Map<String, dynamic> result = _parseAndNormalize(jsonResponse);

      if (result['emergency'] == true) {
        final double confidence =
            (result['confidence'] as num?)?.toDouble() ?? 0.0;
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

  /// Feeds a plain-text symptom description to the LiteRT-LM engine.
  /// Returns [_fallbackResponse] if the model is not yet initialized.
  Future<Map<String, dynamic>> evaluateText(
    String text, {
    String? customPrompt,
  }) async {
    if (!_isInitialized) {
      return Map<String, dynamic>.from(_fallbackResponse);
    }

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

      final Map<String, dynamic> result = _parseAndNormalize(jsonResponse);

      if (result['emergency'] == true) {
        final double confidence =
            (result['confidence'] as num?)?.toDouble() ?? 0.0;
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
