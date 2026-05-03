// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'medplum_auth_service.dart';

/// FHIR R4 REST client for the self-hosted Medplum server.
/// Every public method returns null / empty-list on failure — never throws.
/// All methods guard on [auth.isOnline]; callers fall back to local FHIR SDK.
class MedplumRepository {
  static const _base = 'https://telemed-medplum.duckdns.org/fhir/R4';

  final MedplumAuthService auth;
  final http.Client client;

  MedplumRepository({required this.auth, required this.client});

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers() async {
    final token = await auth.getValidToken();
    return {
      'Content-Type': 'application/fhir+json',
      'Accept': 'application/fhir+json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Extracts resource maps from a FHIR Bundle searchset.
  List<Map<String, dynamic>> _extractEntries(Map<String, dynamic>? bundle) {
    if (bundle == null) return [];
    final entries = bundle['entry'] as List?;
    if (entries == null) return [];
    return entries
        .map((e) =>
            (e as Map<String, dynamic>)['resource'] as Map<String, dynamic>?)
        .where((r) => r != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  // ── Patient ────────────────────────────────────────────────────────────────

  /// Returns the first Patient matching the Romanian CNP identifier, or null.
  Future<Map<String, dynamic>?> getPatientByCnp(String cnp) async {
    if (!await auth.isOnline()) return null;
    try {
      final uri = Uri.parse(
          '$_base/Patient?identifier=urn:oid:1.2.40.0.10.1.4.3.1|$cnp');
      final response = await client.get(uri, headers: await _headers());
      if (response.statusCode == 200) {
        final bundle = jsonDecode(response.body) as Map<String, dynamic>;
        final entries = _extractEntries(bundle);
        return entries.isNotEmpty ? entries.first : null;
      }
      debugPrint(
          'MedplumRepository.getPatientByCnp: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.getPatientByCnp error: $e');
      return null;
    }
  }

  /// Creates a new Patient resource on Medplum. Returns the created resource.
  Future<Map<String, dynamic>?> savePatient(
      Map<String, dynamic> payload) async {
    if (!await auth.isOnline()) return null;
    try {
      final response = await client.post(
        Uri.parse('$_base/Patient'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('MedplumRepository.savePatient: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.savePatient error: $e');
      return null;
    }
  }

  /// Updates an existing Patient resource identified by [id].
  Future<Map<String, dynamic>?> updatePatient(
      String id, Map<String, dynamic> payload) async {
    if (!await auth.isOnline()) return null;
    try {
      final response = await client.put(
        Uri.parse('$_base/Patient/$id'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint(
          'MedplumRepository.updatePatient: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.updatePatient error: $e');
      return null;
    }
  }

  // ── Condition ──────────────────────────────────────────────────────────────

  /// Returns the first Condition for [patientId], or null.
  Future<Map<String, dynamic>?> getConditionForPatient(
      String patientId) async {
    if (!await auth.isOnline()) return null;
    try {
      final uri =
          Uri.parse('$_base/Condition?subject=Patient/$patientId');
      final response = await client.get(uri, headers: await _headers());
      if (response.statusCode == 200) {
        final bundle = jsonDecode(response.body) as Map<String, dynamic>;
        final entries = _extractEntries(bundle);
        return entries.isNotEmpty ? entries.first : null;
      }
      debugPrint(
          'MedplumRepository.getConditionForPatient: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.getConditionForPatient error: $e');
      return null;
    }
  }

  // ── Observation ────────────────────────────────────────────────────────────

  /// Returns all Observations for [patientId], newest first (max 50).
  Future<List<Map<String, dynamic>>> getObservationsForPatient(
      String patientId) async {
    if (!await auth.isOnline()) return [];
    try {
      final uri = Uri.parse(
          '$_base/Observation?subject=Patient/$patientId&_sort=-date&_count=50');
      final response = await client.get(uri, headers: await _headers());
      if (response.statusCode == 200) {
        final bundle = jsonDecode(response.body) as Map<String, dynamic>;
        return _extractEntries(bundle);
      }
      debugPrint(
          'MedplumRepository.getObservationsForPatient: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('MedplumRepository.getObservationsForPatient error: $e');
      return [];
    }
  }

  /// POSTs a new Observation. Returns the created resource or null.
  Future<Map<String, dynamic>?> saveObservation(
      Map<String, dynamic> payload) async {
    if (!await auth.isOnline()) return null;
    try {
      final response = await client.post(
        Uri.parse('$_base/Observation'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint(
          'MedplumRepository.saveObservation: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.saveObservation error: $e');
      return null;
    }
  }

  /// PUTs an updated Observation at [id]. Returns the updated resource or null.
  Future<Map<String, dynamic>?> updateObservation(
      String id, Map<String, dynamic> payload) async {
    if (!await auth.isOnline()) return null;
    try {
      final response = await client.put(
        Uri.parse('$_base/Observation/$id'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint(
          'MedplumRepository.updateObservation: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.updateObservation error: $e');
      return null;
    }
  }

  // ── Appointment ────────────────────────────────────────────────────────────

  /// Returns Appointments for [patientId], optionally filtered by [practitionerId].
  /// IDs must be bare FHIR resource IDs (no "Patient/" or "Practitioner/" prefix).
  Future<List<Map<String, dynamic>>> getAppointments({
    required String patientId,
    String? practitionerId,
  }) async {
    if (!await auth.isOnline()) return [];
    try {
      final params = StringBuffer('patient=Patient/$patientId');
      if (practitionerId != null && practitionerId.isNotEmpty) {
        params.write('&actor=Practitioner/$practitionerId');
      }
      params.write('&_sort=date&_count=50');

      final uri = Uri.parse('$_base/Appointment?$params');
      final response = await client.get(uri, headers: await _headers());
      if (response.statusCode == 200) {
        final bundle = jsonDecode(response.body) as Map<String, dynamic>;
        return _extractEntries(bundle);
      }
      debugPrint(
          'MedplumRepository.getAppointments: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('MedplumRepository.getAppointments error: $e');
      return [];
    }
  }

  /// POSTs a new Appointment payload (full FHIR Appointment JSON).
  Future<Map<String, dynamic>?> saveAppointment(
      Map<String, dynamic> payload) async {
    if (!await auth.isOnline()) return null;
    try {
      final response = await client.post(
        Uri.parse('$_base/Appointment'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint(
          'MedplumRepository.saveAppointment: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.saveAppointment error: $e');
      return null;
    }
  }
}
