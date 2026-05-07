// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'medical_session_provider.dart';

final mostRecentEncounterProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repository = ref.watch(fhirRepositoryProvider);
  final cnp        = ref.watch(loginCnpProvider);
  return repository.getMostRecentEncounter(cnp: cnp);
});

final mostRecentMedicationProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repository = ref.watch(fhirRepositoryProvider);
  final cnp        = ref.watch(loginCnpProvider);
  return repository.getMostRecentMedicationRequest(cnp: cnp);
});
