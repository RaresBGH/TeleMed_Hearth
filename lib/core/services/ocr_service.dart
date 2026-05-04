// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/services.dart';

/// Bridges ML Kit on-device OCR (OcrChannel.kt) for ID-card text extraction.
class OcrService {
  OcrService._();

  static const _channel = MethodChannel('com.example.telemed_k/ocr');

  /// Runs ML Kit text recognition on [imagePath].
  /// Returns the full extracted text, or '' on any failure.
  static Future<String> extractText(String imagePath) async {
    try {
      final result = await _channel.invokeMethod<String>(
          'extractTextFromImage', {'imagePath': imagePath});
      return result ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Finds the first 13-digit sequence in [text] (Romanian CNP format).
  static String? parseCnp(String text) {
    final match = RegExp(r'\b\d{13}\b').firstMatch(text);
    return match?.group(0);
  }

  /// Finds the first Romanian mobile phone number (07XXXXXXXX) in [text].
  static String? parsePhone(String text) {
    final match = RegExp(r'\b07\d{8}\b').firstMatch(text);
    return match?.group(0);
  }
}
