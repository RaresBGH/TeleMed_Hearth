// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/constants/practitioner_constants.dart';
import '../../core/services/medplum_repository.dart';

/// Repository for FHIR data access.
///
/// Online-first: when [_medplum] is provided and the device is online, reads
/// are served from the self-hosted Medplum FHIR server. Writes go to BOTH
/// Medplum (best-effort sync) AND the local FHIR SDK (guaranteed cache).
/// If Medplum is unavailable the local SDK is the sole source of truth.
class FhirRepository {
  static const MethodChannel _channel =
      MethodChannel('com.telemed_k/fhir_engine');

  /// Optional Medplum sync layer. Null = local-only mode.
  final MedplumRepository? _medplum;

  FhirRepository({MedplumRepository? medplum}) : _medplum = medplum;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      await _channel.invokeMethod<void>('initializeDatabase', {
        'enableEncryption': true,
      });
      await _channel.invokeMethod<void>('seedMockData');
    } on PlatformException catch (e) {
      throw Exception(
          'Failed to initialize local FHIR Database securely: Error ${e.code}');
    }
  }

  // ── Patient ────────────────────────────────────────────────────────────────

  /// Looks up a Patient by their 13-digit Romanian CNP.
  /// Online-first: tries Medplum, falls back to local SDK.
  Future<Map<String, dynamic>?> getPatientByCnp(String cnp) async {
    if (_medplum != null) {
      final remote = await _medplum.getPatientByCnp(cnp);
      if (remote != null) return remote;
    }
    try {
      final String? result = await _channel
          .invokeMethod<String>('lookupPatientByCnp', {'cnp': cnp});
      if (result == null) return null;
      return jsonDecode(result) as Map<String, dynamic>;
    } on PlatformException catch (e) {
      debugPrint('FhirRepository.getPatientByCnp: local SDK error ${e.code}');
      return null;
    }
  }

  /// Creates a new Patient resource.
  /// Dual-write: Medplum best-effort + local guaranteed.
  Future<void> savePatient(Map<String, dynamic> patientJson) async {
    if (_medplum != null) {
      final result = await _medplum.savePatient(patientJson);
      if (result == null) {
        debugPrint(
            'FhirRepository.savePatient: Medplum sync failed — local only');
      }
    }
    try {
      final String jsonString = jsonEncode(patientJson);
      await _channel
          .invokeMethod<void>('savePatient', {'resource': jsonString});
    } on PlatformException catch (e) {
      throw Exception(
          'Secure local FHIR Patient Write failed: Error ${e.code}');
    }
  }

  /// Updates an existing Patient resource.
  /// Dual-write: Medplum best-effort + local guaranteed.
  Future<void> updatePatient(Map<String, dynamic> patientJson) async {
    if (_medplum != null) {
      final id = patientJson['id'] as String?;
      if (id != null) {
        final result = await _medplum.updatePatient(id, patientJson);
        if (result == null) {
          debugPrint(
              'FhirRepository.updatePatient: Medplum sync failed — local only');
        }
      }
    }
    try {
      final String jsonString = jsonEncode(patientJson);
      await _channel
          .invokeMethod<void>('updatePatient', {'resource': jsonString});
    } on PlatformException catch (e) {
      throw Exception(
          'Secure local FHIR Patient Update failed: Error ${e.code}');
    }
  }

  /// Deletes all FHIR resources for [cnp]. Used during account deletion.
  Future<void> deleteAllForPatient(String cnp) async {
    try {
      await _channel.invokeMethod<void>('deletePatientData', {'cnp': cnp});
    } on PlatformException catch (e) {
      throw Exception(
          'Secure local FHIR Patient Delete failed: Error ${e.code}');
    }
  }

  // ── Observation ────────────────────────────────────────────────────────────

  /// Saves an Observation from a triage session.
  /// Dual-write: Medplum best-effort + local guaranteed.
  Future<void> saveObservation(
      Map<String, dynamic> observationJson) async {
    if (_medplum != null) {
      final result = await _medplum.saveObservation(observationJson);
      if (result == null) {
        debugPrint(
            'FhirRepository.saveObservation: Medplum sync failed — local only');
      }
    }
    try {
      final String jsonString = jsonEncode(observationJson);
      await _channel.invokeMethod<void>(
          'saveObservation', {'resource': jsonString});
    } on PlatformException catch (e) {
      throw Exception(
          'Secure local FHIR Observation Write failed: Error ${e.code}');
    }
  }

  /// Updates an existing Observation (resume-conversation flow).
  /// Dual-write: Medplum best-effort + local guaranteed.
  Future<void> updateObservation(
      String id, Map<String, dynamic> observationJson) async {
    final payload = Map<String, dynamic>.from(observationJson);
    payload['id'] = id;

    if (_medplum != null) {
      final result = await _medplum.updateObservation(id, payload);
      if (result == null) {
        debugPrint(
            'FhirRepository.updateObservation: Medplum sync failed — local only');
      }
    }
    try {
      final String jsonString = jsonEncode(payload);
      await _channel.invokeMethod<void>(
          'updateObservation', {'resource': jsonString});
    } on PlatformException catch (e) {
      throw Exception(
          'Secure local FHIR Observation Update failed: Error ${e.code}');
    }
  }

  // ── Condition ──────────────────────────────────────────────────────────────

  Future<void> saveCondition(Map<String, dynamic> conditionJson) async {
    try {
      final String jsonString = jsonEncode(conditionJson);
      await _channel
          .invokeMethod<void>('saveCondition', {'resource': jsonString});
    } on PlatformException catch (e) {
      throw Exception(
          'Secure local FHIR Condition Write failed: Error ${e.code}');
    }
  }

  // ── History ────────────────────────────────────────────────────────────────

  /// Returns Observations and Conditions for [cnp].
  /// Online-first: fetches both from Medplum, merges, falls back to local SDK.
  Future<List<Map<String, dynamic>>> getPatientHistory(
      {String cnp = ''}) async {
    if (_medplum != null && cnp.isNotEmpty) {
      final patient = await _medplum.getPatientByCnp(cnp);
      final patientId = patient?['id'] as String?;
      if (patientId != null) {
        final observations =
            await _medplum.getObservationsForPatient(patientId);

        // Also fetch Conditions from Medplum and merge into the result.
        List<Map<String, dynamic>> conditions = [];
        try {
          final condition = await _medplum.getConditionForPatient(patientId);
          if (condition != null) conditions = [condition];
        } catch (e) {
          debugPrint(
              'FhirRepository.getPatientHistory: Medplum Condition fetch error: $e');
        }

        final merged = [...observations, ...conditions];
        if (merged.isNotEmpty) return merged;
      }
    }
    try {
      final String? result = await _channel.invokeMethod<String>(
        'getPatientHistory',
        {'cnp': cnp},
      );
      if (result == null) return [];
      final List<dynamic> parsed = jsonDecode(result) as List<dynamic>;
      return parsed.cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      debugPrint('FhirRepository.getPatientHistory: local SDK error ${e.code}');
      return [];
    }
  }

  // ── Appointments ───────────────────────────────────────────────────────────

  /// Returns Appointments for [cnp], optionally scoped to [practitionerRef].
  /// Online-first: tries Medplum, falls back to local SDK.
  Future<List<Map<String, dynamic>>> getAppointments(
      {required String cnp, String? practitionerRef}) async {
    if (_medplum != null) {
      final patient = await _medplum.getPatientByCnp(cnp);
      final patientId = patient?['id'] as String?;
      if (patientId != null) {
        // Strip "Practitioner/" prefix if present before passing to Medplum.
        final practId = practitionerRef?.replaceFirst('Practitioner/', '');
        final appointments = await _medplum.getAppointments(
          patientId: patientId,
          practitionerId: (practId == 'family' || practId == null)
              ? null
              : practId,
        );
        if (appointments.isNotEmpty) return appointments;
      }
    }
    try {
      // Strip 'Practitioner/' prefix before passing to Kotlin — the native filter
      // builds "Practitioner/$value" itself, so passing the full ref would double-prefix.
      final bareRef = practitionerRef?.startsWith('Practitioner/') == true
          ? practitionerRef!.substring('Practitioner/'.length)
          : practitionerRef;
      final String? result = await _channel.invokeMethod<String>(
          'getAppointments', {
        'cnp': cnp,
        if (bareRef != null) 'practitionerRef': bareRef,
      });
      if (result == null) return [];
      final List<dynamic> parsed = jsonDecode(result) as List<dynamic>;
      return parsed.cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      debugPrint('FhirRepository.getAppointments: local SDK error ${e.code}');
      return [];
    }
  }

  /// Saves a new Appointment booking.
  /// Dual-write: Medplum best-effort + local guaranteed.
  ///
  /// [data] keys: patientId (CNP), practitionerId, dateTimeIso,
  /// durationMinutes, description, status.
  Future<void> saveAppointment({required Map<String, dynamic> data}) async {
    if (_medplum != null) {
      // Look up the patient's Medplum FHIR ID so the Appointment participant
      // uses a direct reference (Patient/{id}) instead of a CNP identifier.
      // Medplum does not resolve chained identifier searches on Appointment queries,
      // so CNP-based references cause getAppointments to return empty results.
      final cnp = data['patientId'] as String? ?? '';
      String? medplumPatientId;
      if (cnp.isNotEmpty) {
        final patient = await _medplum.getPatientByCnp(cnp);
        medplumPatientId = patient?['id'] as String?;
      }
      final fhirPayload = _buildFhirAppointmentPayload(
          data, medplumPatientId: medplumPatientId);
      final result = await _medplum.saveAppointment(fhirPayload);
      if (result == null) {
        debugPrint(
            'FhirRepository.saveAppointment: Medplum sync failed — local only');
      }
    }
    try {
      await _channel.invokeMethod<void>('saveAppointment', data);
    } on PlatformException catch (e) {
      throw Exception(
          'Secure local FHIR Appointment Write failed: Error ${e.code}');
    }
  }

  // ── Encounter / Medication ────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getMostRecentEncounter() async {
    try {
      final String? result =
          await _channel.invokeMethod<String>('getMostRecentEncounter');
      if (result == null) return null;
      return jsonDecode(result) as Map<String, dynamic>;
    } on PlatformException catch (e) {
      debugPrint('FhirRepository.getMostRecentEncounter: local SDK error ${e.code}');
      return null;
    }
  }

  /// Returns the most recent active MedicationRequest for [cnp].
  /// Online-first when [cnp] is provided: queries Medplum for the patient's
  /// active medications, falls back to local FHIR SDK.
  Future<Map<String, dynamic>?> getMostRecentMedicationRequest({String cnp = ''}) async {
    if (_medplum != null && cnp.isNotEmpty) {
      try {
        final patient = await _medplum.getPatientByCnp(cnp);
        final patientId = patient?['id'] as String?;
        if (patientId != null) {
          const medplumBase = 'https://telemed-medplum.duckdns.org/fhir/R4';
          final token = await _medplum.auth.getValidToken();
          if (token != null) {
            final response = await _medplum.client.get(
              Uri.parse(
                '$medplumBase/MedicationRequest'
                '?patient=Patient/$patientId'
                '&status=active&_sort=-date&_count=1',
              ),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/fhir+json',
              },
            );
            if (response.statusCode == 200) {
              final bundle = jsonDecode(response.body) as Map<String, dynamic>;
              final entries = bundle['entry'] as List?;
              if (entries != null && entries.isNotEmpty) {
                final resource =
                    (entries.first as Map)['resource'] as Map<String, dynamic>?;
                if (resource != null) return resource;
              }
            } else {
              debugPrint(
                  'FhirRepository.getMostRecentMedicationRequest: Medplum ${response.statusCode}');
            }
          }
        }
      } catch (e) {
        debugPrint('FhirRepository.getMostRecentMedicationRequest: Medplum error: $e');
      }
    }
    // Local FHIR SDK fallback (unchanged).
    try {
      final String? result = await _channel
          .invokeMethod<String>('getMostRecentMedicationRequest');
      if (result == null) return null;
      return jsonDecode(result) as Map<String, dynamic>;
    } on PlatformException catch (e) {
      debugPrint('FhirRepository.getMostRecentMedicationRequest: local SDK error ${e.code}');
      return null;
    }
  }

  Future<void> updateEncounterConsent(String callId) async {
    try {
      await _channel.invokeMethod<void>(
          'updateEncounterConsent', {'callId': callId, 'consent': true});
    } on PlatformException catch (e) {
      throw Exception(
          'Secure local FHIR Consent Write failed: Error ${e.code}');
    }
  }

  // ── Sync utilities ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUnsyncedResources() async {
    try {
      final String? result =
          await _channel.invokeMethod<String>('getUnsyncedResources');
      if (result == null) return [];
      final List<dynamic> parsed = jsonDecode(result) as List<dynamic>;
      return parsed.cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      debugPrint('FhirRepository.getUnsyncedResources: local SDK error ${e.code}');
      return [];
    }
  }

  Future<void> markAsSynced(List<String> resourceIds) async {
    try {
      await _channel
          .invokeMethod<void>('markAsSynced', {'resourceIds': resourceIds});
    } on PlatformException catch (e) {
      throw Exception(
          'Secure local FHIR Mark Synced failed: Error ${e.code}');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Converts the raw appointment data map (local format) into a FHIR
  /// Appointment JSON payload suitable for posting to Medplum.
  ///
  /// When [medplumPatientId] is provided the patient participant uses a direct
  /// `Patient/{id}` reference so Medplum can match it in getAppointments queries.
  /// Falls back to the CNP identifier actor when the Medplum ID is unavailable.
  static Map<String, dynamic> _buildFhirAppointmentPayload(
      Map<String, dynamic> data, {String? medplumPatientId}) {
    final cnp = data['patientId'] as String? ?? '';
    final practRef = data['practitionerId'] as String? ?? '';
    final dateTimeIso = data['dateTimeIso'] as String? ?? '';
    final durationMinutes =
        (data['durationMinutes'] as num?)?.toInt() ?? 30;
    final description = data['description'] as String? ?? '';
    final status = data['status'] as String? ?? 'booked';

    DateTime? start;
    DateTime? end;
    if (dateTimeIso.isNotEmpty) {
      try {
        start = DateTime.parse(dateTimeIso);
        end = start.add(Duration(minutes: durationMinutes));
      } catch (_) {}
    }

    // Resolve practitioner reference: "family" or empty falls back to family doctor.
    final resolvedPractRef =
        (practRef == 'family' || practRef.isEmpty)
            ? Practitioners.familyDoctorId
            : (practRef.startsWith('Practitioner/')
                ? practRef
                : 'Practitioner/$practRef');

    return {
      'resourceType': 'Appointment',
      'status': status,
      'description': description,
      if (start != null) 'start': start.toUtc().toIso8601String(),
      if (end != null) 'end': end.toUtc().toIso8601String(),
      'participant': [
        // Use a direct Patient reference when the Medplum ID is known;
        // fall back to CNP identifier for offline / seeded patients.
        if (medplumPatientId != null)
          {
            'actor': {'reference': 'Patient/$medplumPatientId'},
            'status': 'accepted',
          }
        else
          {
            'actor': {
              'type': 'Patient',
              'identifier': {
                'system': 'urn:oid:1.2.40.0.10.1.4.3.1',
                'value': cnp,
              },
            },
            'status': 'accepted',
          },
        {
          'actor': {'reference': resolvedPractRef},
          'status': 'accepted',
        },
      ],
    };
  }
}
