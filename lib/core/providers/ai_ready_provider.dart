// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/medical_session_provider.dart';

/// Shared AI readiness flag. Runs [AiEngineService.initializeModel] once per
/// app session and caches the result so both HomeScreen and DashboardScreen
/// display the same status without creating redundant instances.
/// Uses [aiEngineServiceProvider] so the same singleton instance is reused.
final aiReadyProvider = FutureProvider<bool>((ref) async {
  return ref.read(aiEngineServiceProvider).initializeModel();
});
