// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../services/medplum_auth_service.dart';
import '../services/medplum_repository.dart';

/// Singleton provider for the Medplum OAuth service.
/// Injected wherever a Medplum API call needs a valid bearer token.
final medplumAuthServiceProvider = Provider<MedplumAuthService>((ref) {
  return MedplumAuthService(
    storage: const FlutterSecureStorage(),
    client: http.Client(),
  );
});

/// Singleton provider for the Medplum FHIR REST repository.
/// Injected into FhirRepository as the online sync layer.
final medplumRepositoryProvider = Provider<MedplumRepository>((ref) {
  return MedplumRepository(
    auth: ref.watch(medplumAuthServiceProvider),
    client: http.Client(),
  );
});
