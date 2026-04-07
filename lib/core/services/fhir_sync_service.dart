// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/repositories/fhir_repository.dart';

/// Bridges the local SQLite FHIR SDK to the remote Medplum EHR securely
/// across intermittent network connections.
class FhirSyncService {
  static const String _medplumFhirUrl = 'https://api.medplum.com/fhir/R4';
  
  final Connectivity _connectivity = Connectivity();
  final FhirRepository _fhirRepository = FhirRepository();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  String? _bearerToken;
  bool _isSyncing = false;

  /// Starts listening to network conditions to perform sync securely on restoral.
  void initializeNetworkListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.mobile)) {
        _triggerRemoteSync();
      }
    });
  }

  /// Sets the OAuth2 Bearer token securely for Medplum Auth.
  Future<void> setAuthToken(String token) async {
    _bearerToken = token;
    // Attempt sync immediately if token is acquired and network is available
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.mobile)) {
      _triggerRemoteSync();
    }
  }

  /// Evaluates current state and synchronizes local records to the Medplum cloud.
  Future<void> _triggerRemoteSync() async {
    if (_isSyncing || _bearerToken == null) return;
    
    _isSyncing = true;
    try {
      final unsynced = await _fhirRepository.getUnsyncedResources();
      if (unsynced.isEmpty) {
        _isSyncing = false;
        return;
      }

      // Filter to only Encounter, Observation, and Condition resources to protect data sanity
      final targets = ['Encounter', 'Observation', 'Condition'];
      final resourcesToSync = unsynced.where((res) => targets.contains(res['resourceType'])).toList();

      if (resourcesToSync.isEmpty) {
        _isSyncing = false;
        return;
      }

      // Build FHIR Transaction Bundle
      final bundle = {
        'resourceType': 'Bundle',
        'type': 'transaction',
        'entry': resourcesToSync.map((resource) {
          final id = resource['id'] ?? '';
          return {
            'resource': resource,
            'request': {
              'method': id.isNotEmpty ? 'PUT' : 'POST',
              'url': id.isNotEmpty ? '${resource['resourceType']}/$id' : resource['resourceType'],
            }
          };
        }).toList(),
      };

      final response = await http.post(
        Uri.parse(_medplumFhirUrl),
        headers: {
          'Content-Type': 'application/fhir+json',
          'Authorization': 'Bearer $_bearerToken',
        },
        body: jsonEncode(bundle),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successful sync, mark local resources as synced
        final syncedIds = resourcesToSync
            .map((res) => res['id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList();
            
        if (syncedIds.isNotEmpty) {
          await _fhirRepository.markAsSynced(syncedIds);
        }
      } else {
        debugPrint('Medplum sync failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Sync Engine Exception: Offline Restoral Deferred.');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
