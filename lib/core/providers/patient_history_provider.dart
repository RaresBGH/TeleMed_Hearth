// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'medical_session_provider.dart';

/// Fetches the FHIR history (Observations + Conditions) for the currently
/// logged-in patient only, filtered by their CNP on the native FHIR SDK side.
final patientHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(fhirRepositoryProvider);
  final cnp        = ref.watch(loginCnpProvider);
  return repository.getPatientHistory(cnp: cnp);
});

/// Fetches FHIR Appointments for the currently logged-in patient.
/// Sorted by the native layer (upcoming-asc, past-desc); Dart side mirrors
/// the same sort as a safety guard.
final appointmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(fhirRepositoryProvider);
  final cnp        = ref.watch(loginCnpProvider);
  return repository.getAppointments(cnp: cnp);
});
