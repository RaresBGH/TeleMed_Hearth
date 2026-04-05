// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:convert';
import 'package:flutter/services.dart';

/// Repository responsible for interfacing with the Google Android FHIR SDK.
/// Uses a MethodChannel to handle offline SQLite storage of Observation and Condition resources.
class FhirRepository {
  static const MethodChannel _channel = MethodChannel('com.telemed_k/fhir_engine');

  /// Initializes the local FHIR SDK engine and encrypted SQLite database.
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod<void>('initializeDatabase');
    } on PlatformException catch (e) {
      throw Exception('Failed to initialize FHIR Database: ${e.message}');
    }
  }

  /// Saves a parsed FHIR Observation resource from the local AI session.
  Future<void> saveObservation(Map<String, dynamic> observationJson) async {
    try {
      final String jsonString = jsonEncode(observationJson);
      await _channel.invokeMethod<void>('saveObservation', {'resource': jsonString});
    } on PlatformException catch (e) {
      throw Exception('Failed to save Observation: ${e.message}');
    }
  }

  /// Saves a parsed FHIR Condition resource (e.g. inferred from audio).
  Future<void> saveCondition(Map<String, dynamic> conditionJson) async {
    try {
      final String jsonString = jsonEncode(conditionJson);
      await _channel.invokeMethod<void>('saveCondition', {'resource': jsonString});
    } on PlatformException catch (e) {
      throw Exception('Failed to save Condition: ${e.message}');
    }
  }

  /// Returns resources buffered for cloud sync once connection is restored.
  Future<List<Map<String, dynamic>>> getUnsyncedResources() async {
    try {
      final String? result = await _channel.invokeMethod<String>('getUnsyncedResources');
      if (result == null) return [];
      
      final List<dynamic> parsed = jsonDecode(result) as List<dynamic>;
      return parsed.cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      throw Exception('Failed to get unsynced resources: ${e.message}');
    }
  }

  /// Returns all historical Observation and Condition resources for the active patient
  /// securely from the local encrypted SQLite DB to serve as context for the AI Engine.
  Future<List<Map<String, dynamic>>> getPatientHistory() async {
    try {
      final String? result = await _channel.invokeMethod<String>('getPatientHistory');
      if (result == null) return [];
      
      final List<dynamic> parsed = jsonDecode(result) as List<dynamic>;
      return parsed.cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      throw Exception('Failed to get patient history: ${e.message}');
    }
  }
}
