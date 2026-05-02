// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/medical_session_provider.dart';
import '../services/ai_engine_service.dart';

/// Shared AI readiness flag. Runs [AiEngineService.initializeModel] once per
/// app session and caches the result so both HomeScreen and DashboardScreen
/// display the same status without creating redundant instances.
/// Uses [fhirRepositoryProvider] so no extra FhirRepository is allocated.
final aiReadyProvider = FutureProvider<bool>((ref) async {
  return AiEngineService(ref.read(fhirRepositoryProvider)).initializeModel();
});
