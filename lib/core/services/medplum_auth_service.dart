// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'fhir_sync_service.dart';

/// Service responsible for handling authentication via Medplum.
/// It uses the provided CNP/Phone and OTP to obtain an OAuth2 token securely.
class MedplumAuthService {
  // SMART-on-FHIR Configuration Placeholders
  // ignore: unused_field
  static const String _smartAuthUri = 'https://api.medplum.com/oauth2/authorize';
  static const String _smartTokenUri = 'https://api.medplum.com/oauth2/token';
  // ignore: unused_field
  static const String _smartJwksUri = 'https://api.medplum.com/oauth2/jwks';
  static const String _clientId = 'telemed_k_mobile_client'; // Client ID
  // ignore: unused_field
  static const String _redirectUri = 'telemed-k://callback'; // Native custom scheme

  final FhirSyncService _syncService = FhirSyncService();

  /// Authenticate with Medplum using the CNP as the username and OTP as the password.
  /// This simulates a custom identity provider flow configured on Medplum.
  Future<bool> authenticateWithOTP(String cnp, String otp) async {
    try {
      final response = await http.post(
        Uri.parse(_smartTokenUri),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'password',
          'client_id': _clientId,
          'username': cnp,
          'password': otp,
          'scope': 'openid profile fhirUser offline_access patient/*.*',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        
        // Securely pass the token to the Native FHIR Sync Engine
        await _syncService.setAuthToken(accessToken);
        return true;
      } else {
        // Log generic error to prevent PHI/PII leakage
        debugPrint('Medplum Authentication Failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Medplum Authentication Exception: Secure Error');
      return false;
    }
  }
}

final medplumAuthServiceProvider = Provider<MedplumAuthService>((ref) {
  return MedplumAuthService();
});
