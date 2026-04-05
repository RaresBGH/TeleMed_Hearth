// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Bridges to the Android FHIR SDK Native SyncManager to push 
/// offline records into a remote FHIR EHR (e.g. Medplum or Aidbox)
class FhirSyncService {
  static const MethodChannel _channel = MethodChannel('com.telemed_k/fhir_engine');
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Starts listening to network conditions to perform sync securely on restoral.
  void initializeNetworkListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Trigger sync ONLY when a stable Wi-Fi or 4G (mobile) connection is detected
      if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.mobile)) {
        _triggerRemoteSync();
      }
    });
  }

  /// Evaluates current state and dynamically bounds the Native Worker securely.
  Future<void> _triggerRemoteSync() async {
    try {
      // Explicit constraints applied securely isolating strictly Observations/Conditions
      await _channel.invokeMethod<void>('executeSync', {
        'remoteServerUrl': 'https://api.medplum.com/fhir/R4',
        'authStrategy': 'BearerToken', // OAuth2 implementation mapping
        'resourcesToSync': ['Observation', 'Condition'],
      });
    } on PlatformException catch (e) {
      throw Exception('OAuth2 Native FHIR Sync failed: ${e.message}');
    }
  }

  /// Sets the OAuth2 Bearer token securely in the native Android Engine vault.
  Future<void> setAuthToken(String token) async {
    try {
      await _channel.invokeMethod<void>('setAuthToken', {'token': token});
    } on PlatformException catch (e) {
      throw Exception('Securing Offline Vault Failed: ${e.message}');
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
