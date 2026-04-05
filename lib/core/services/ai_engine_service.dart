// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Exception thrown when the AI rules engine detects life-threatening conditions.
class EmergencyFlagException implements Exception {
  final double confidence;
  EmergencyFlagException(this.confidence);
  
  @override
  String toString() => 'EMERGENCY FLAG TRIGGERED: Life-threatening condition detected (Confidence: $confidence)';
}

/// Service handling local AI Inference via Google LiteRT-LM (Gemma 4 E2B)
class AiEngineService {
  static const MethodChannel _channel = MethodChannel('com.telemed_k/litert_lm');
  static const String _modelFileName = 'gemma4_e2b_4bit.gguf';

  bool _isModelInitialized = false;

  /// Checks Wi-Fi connection, downloads the ~2.58 GB 4-bit quantized 
  /// Gemma 4 E2B model weights, and saves them to local device storage.
  /// Intended to run on the very first app launch; avoids bundling weights in the APK.
  Future<void> downloadWeights(String storageDirectory) async {
    try {
      final String downloadPath = '$storageDirectory/$_modelFileName';
      await _channel.invokeMethod<void>('downloadWeights', {
        'destinationPath': downloadPath,
        'modelUrl': 'https://storage.googleapis.com/telemed_k_assets/gemma4_e2b_4bit.gguf',
        'requireWiFi': true, // Native level implementation forcefully prompts user for Wi-Fi
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to download Gemma 4 E2B weights: ${e.message}');
    }
  }

  /// Loads the locally downloaded weights into the LiteRT-LM framework memory space.
  Future<void> initializeModel(String storageDirectory) async {
    try {
      final String modelPath = '$storageDirectory/$_modelFileName';
      await _channel.invokeMethod<void>('initializeModel', {
        'modelPath': modelPath,
      });
      _isModelInitialized = true;
    } on PlatformException catch (e) {
      throw Exception('Failed to initialize LiteRT-LM model: ${e.message}');
    }
  }

  /// Feeds the raw collected audio file DIRECTLY to the LiteRT-LM model.
  /// Leverages Gemma 4 E2B's native audio input capabilities (No external STT used).
  /// Expects constrained JSON output outlining the medical analysis.
  Future<Map<String, dynamic>> evaluateAudio(File audioFile) async {
    if (!_isModelInitialized) {
      throw Exception('AI model must be initialized before processing audio.');
    }

    try {
      // Passes the raw audio path into the LiteRT-LM framework.
      final String? jsonResponse = await _channel.invokeMethod<String>('evaluateAudio', {
        'audioPath': audioFile.path,
        'constraintFormat': 'json',
      });

      if (jsonResponse == null || jsonResponse.isEmpty) {
        throw Exception('LiteRT-LM returned null or an empty response.');
      }

      final Map<String, dynamic> result = jsonDecode(jsonResponse) as Map<String, dynamic>;

      // Rules Engine: Check for emergency flag based on constrained JSON response
      if (result.containsKey('emergency') && result['emergency'] == true) {
        final double confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
        
        // Throw an emergency state flag if confidence > 0.8
        if (confidence > 0.8) {
          throw EmergencyFlagException(confidence);
        }
      }

      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to evaluate audio via AI model: ${e.message}');
    }
  }
}
