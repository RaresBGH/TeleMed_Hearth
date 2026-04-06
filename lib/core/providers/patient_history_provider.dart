// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'medical_session_provider.dart';

final patientHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(fhirRepositoryProvider);
  return repository.getPatientHistory();
});
