// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'medplum_auth_service.dart';
import '../utils/fhir_extension_utils.dart';

/// FHIR R4 REST client for the self-hosted Medplum server.
/// Every public method returns null / empty-list on failure — never throws.
/// All methods guard on [auth.isOnline]; callers fall back to local FHIR SDK.
class MedplumRepository {
  static const _base = 'https://telemed-medplum.duckdns.org/fhir/R4';

  /// Public accessor so callers (e.g. FhirRepository) can build URLs without
  /// duplicating the base URL string.
  static String get base => _base;

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
  /// On 401: clears the cached token and retries once (token expiry / rotation).
  /// On any failure: logs and returns null — callers must NOT block on this.
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
      if (response.statusCode == 401) {
        debugPrint(
            'MedplumRepository.savePatient: 401 Unauthorized — '
            'check client credentials (dart-define MEDPLUM_CLIENT_ID/SECRET). '
            'Clearing cached token and retrying once.');
        await auth.clearToken();
        final token = await auth.getValidToken();
        if (token == null) {
          debugPrint('MedplumRepository.savePatient: retry aborted — no valid token. '
              'Local FHIR write will proceed.');
          return null;
        }
        final retry = await client.post(
          Uri.parse('$_base/Patient'),
          headers: await _headers(),
          body: jsonEncode(payload),
        );
        if (retry.statusCode == 200 || retry.statusCode == 201) {
          debugPrint('MedplumRepository.savePatient: retry succeeded');
          return jsonDecode(retry.body) as Map<String, dynamic>;
        }
        debugPrint('MedplumRepository.savePatient: retry also failed '
            '${retry.statusCode}. Local FHIR write will proceed.');
        return null;
      }
      final snippet = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
      debugPrint(
          'MedplumRepository.savePatient: HTTP ${response.statusCode} — $snippet. '
          'Local FHIR write will proceed.');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.savePatient exception: $e. '
          'Local FHIR write will proceed.');
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

  // ── Communication ──────────────────────────────────────────────────────────

  /// Saves an in-call or async text message as a FHIR Communication resource.
  /// Never throws — returns null when offline or on server error.
  Future<Map<String, dynamic>?> saveCommunication({
    required String patientCnp,
    String? appointmentId,
    String? observationId,
    required String text,
    required bool isPatient,
    required DateTime timestamp,
    String? attachmentPath,
    String? mimeType,
    String? attachmentTitle,
    String? practitionerId,
  }) async {
    if (!await auth.isOnline()) return null;
    try {
      final patientRef = {
        'type': 'Patient',
        'identifier': {
          'system': 'urn:oid:1.2.40.0.10.1.4.3.1',
          'value': patientCnp,
        },
      };
      final practRef = practitionerId != null && practitionerId.isNotEmpty
          ? {'reference': 'Practitioner/$practitionerId'}
          : null;

      final payload = <String, dynamic>{
        'resourceType': 'Communication',
        'status': 'completed',
        'sent': timestamp.toUtc().toIso8601String(),
        'subject': patientRef,
        // sender: the party that sent the message.
        'sender': isPatient ? patientRef : (practRef ?? <String, dynamic>{}),
        // recipient: the intended receiver of the message.
        'recipient': [isPatient ? (practRef ?? <String, dynamic>{}) : patientRef],
        if (observationId != null && observationId.isNotEmpty)
          'about': [{'reference': 'Observation/$observationId'}]
        else if (appointmentId != null && appointmentId.isNotEmpty)
          'about': [{'reference': 'Appointment/$appointmentId'}],
        'payload': [
          {'contentString': text},
          if (mimeType != null && attachmentTitle != null)
            {
              'contentAttachment': {
                'contentType': mimeType,
                'title': attachmentTitle,
                'creation': timestamp.toUtc().toIso8601String(),
              }
            },
        ],
        // Keep isPatient extension for backwards compatibility.
        'extension': [
          {'url': FhirExtensionUtils.isPatientUrl, 'valueBoolean': isPatient},
        ],
      };
      final response = await client.post(
        Uri.parse('$_base/Communication'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('MedplumRepository.saveCommunication: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.saveCommunication error: $e');
      return null;
    }
  }

  /// Returns Communication resources for [patientId], newest first (max 50).
  /// [since] filters by sent timestamp. [aboutReference] filters by about (e.g. 'Observation/{id}').
  Future<List<Map<String, dynamic>>> getCommunications(String patientId, {DateTime? since, String? aboutReference}) async {
    if (!await auth.isOnline()) return [];
    try {
      final sinceParam = since != null
          ? '&sent=ge${Uri.encodeComponent(since.toUtc().toIso8601String())}'
          : '';
      final aboutParam = aboutReference != null && aboutReference.isNotEmpty
          ? '&about=${Uri.encodeComponent(aboutReference)}'
          : '';
      final uri = Uri.parse(
          '$_base/Communication?subject=Patient/$patientId&_sort=sent&_count=50$sinceParam$aboutParam');
      final response = await client.get(uri, headers: await _headers());
      if (response.statusCode == 200) {
        final bundle = jsonDecode(response.body) as Map<String, dynamic>;
        return _extractEntries(bundle);
      }
      debugPrint('MedplumRepository.getCommunications: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('MedplumRepository.getCommunications error: $e');
      return [];
    }
  }

  /// Patches an Observation's valueString and extension list.
  /// Used for summary refresh after a doctor marks an Observation as reviewed.
  Future<void> patchObservationValueString({
    required String obsId,
    required String newSummary,
    required List<Map<String, dynamic>> updatedExtensions,
  }) async {
    if (!await auth.isOnline()) return;
    try {
      final response = await client.patch(
        Uri.parse('$_base/Observation/$obsId'),
        headers: {
          ...await _headers(),
          'Content-Type': 'application/json-patch+json',
        },
        body: jsonEncode([
          {'op': 'replace', 'path': '/valueString', 'value': newSummary},
          {'op': 'replace', 'path': '/extension', 'value': updatedExtensions},
        ]),
      );
      if (response.statusCode != 200) {
        debugPrint('MedplumRepository.patchObservationValueString: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('MedplumRepository.patchObservationValueString error: $e');
    }
  }

  // ── DocumentReference ──────────────────────────────────────────────────────

  /// Records a file attachment as a FHIR DocumentReference.
  /// [patientCnp] is used as a logical identifier — Medplum resolves the Patient.
  /// Never throws; returns null when offline or on server error.
  Future<Map<String, dynamic>?> saveDocumentReference({
    required String patientCnp,
    required String filePath,
    required String mimeType,
    required String description,
  }) async {
    if (!await auth.isOnline()) return null;
    try {
      final payload = {
        'resourceType': 'DocumentReference',
        'status': 'current',
        'subject': {
          'type': 'Patient',
          'identifier': {
            'system': 'urn:oid:1.2.40.0.10.1.4.3.1',
            'value': patientCnp,
          },
        },
        'content': [
          {
            'attachment': {
              'contentType': mimeType,
              'title': description,
              'creation': DateTime.now().toUtc().toIso8601String(),
            }
          }
        ],
      };
      final response = await client.post(
        Uri.parse('$_base/DocumentReference'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('MedplumRepository.saveDocumentReference: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MedplumRepository.saveDocumentReference error: $e');
      return null;
    }
  }
}
