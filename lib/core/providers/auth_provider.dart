// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/fhir_repository.dart';

/// Temporarily stores the CNP entered on the Identity Screen
/// so it can be used on the Verification Screen.
class LoginCnpNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setCnp(String cnp) {
    state = cnp;
  }
}

final loginCnpProvider = NotifierProvider<LoginCnpNotifier, String>(() {
  return LoginCnpNotifier();
});

// ── Patient auth state ────────────────────────────────────────────────────────

class PatientAuthState {
  final bool isReturningUser;
  final String? patientFirstName;
  const PatientAuthState({this.isReturningUser = false, this.patientFirstName});
}

/// Looks up or creates the active patient after OTP verification.
class PatientAuthNotifier extends Notifier<PatientAuthState> {
  @override
  PatientAuthState build() => const PatientAuthState();

  /// Searches the local FHIR DB for a Patient whose CNP identifier matches [cnp].
  /// Returns true (returning user, name loaded into state) or false (new user).
  Future<bool> loadPatient(String cnp) async {
    try {
      final patient = await FhirRepository().getPatientByCnp(cnp);
      if (patient != null) {
        final nameList = patient['name'] as List?;
        String? firstName;
        if (nameList != null && nameList.isNotEmpty) {
          final nameMap = nameList.first as Map<String, dynamic>?;
          final givenList = nameMap?['given'] as List?;
          if (givenList != null && givenList.isNotEmpty) {
            firstName = givenList.first as String?;
          }
        }
        state = PatientAuthState(isReturningUser: true, patientFirstName: firstName);
        return true;
      }
      state = const PatientAuthState(isReturningUser: false);
      return false;
    } catch (e) {
      debugPrint('PatientAuthNotifier.loadPatient error: $e');
      state = const PatientAuthState(isReturningUser: false);
      return false;
    }
  }

  /// Creates a new FHIR Patient resource and stores the first name in state.
  Future<void> registerNewPatient({
    required String cnp,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    await FhirRepository().savePatient({
      'resourceType': 'Patient',
      'identifier': [
        {'system': 'urn:oid:1.2.40.0.10.1.4.3.1', 'value': cnp}
      ],
      'name': [
        {'family': lastName, 'given': [firstName]}
      ],
      'telecom': [
        {'system': 'phone', 'value': phone, 'use': 'mobile'}
      ],
    });
    state = PatientAuthState(isReturningUser: true, patientFirstName: firstName);
  }
}

final patientAuthProvider =
    NotifierProvider<PatientAuthNotifier, PatientAuthState>(
        PatientAuthNotifier.new);
