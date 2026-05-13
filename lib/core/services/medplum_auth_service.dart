// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Manages OAuth 2.0 client_credentials tokens for the self-hosted Medplum
/// FHIR server. Tokens are persisted in FlutterSecureStorage and refreshed
/// automatically with a 60-second buffer before expiry.
class MedplumAuthService {
  // ── OAuth / Medplum constants ──────────────────────────────────────────────
  static const _tokenUrl =
      'https://telemed-medplum.duckdns.org/oauth2/token';
  static const _clientId = String.fromEnvironment(
    'MEDPLUM_CLIENT_ID',
    defaultValue: '',
  );
  static const _clientSecret = String.fromEnvironment(
    'MEDPLUM_CLIENT_SECRET',
    defaultValue: '',
  );

  // ── Secure-storage keys ────────────────────────────────────────────────────
  static const _storageKeyToken  = 'medplum_access_token';
  static const _storageKeyExpiry = 'medplum_token_expiry';

  // ── Expiry buffer: consider token stale 60 s before it actually expires ───
  static const _expiryBuffer = Duration(seconds: 60);

  // ── Dependencies ───────────────────────────────────────────────────────────
  final FlutterSecureStorage _storage;
  final http.Client _client;

  // ── In-memory cache ────────────────────────────────────────────────────────
  String?   _cachedToken;
  DateTime? _tokenExpiry;

  MedplumAuthService({
    required FlutterSecureStorage storage,
    required http.Client client,
  })  : _storage = storage,
        _client  = client;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns a valid access token, refreshing if necessary.
  /// Returns null if offline or if the token fetch fails.
  Future<String?> getValidToken() async {
    // 1. Memory cache
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(_expiryBuffer))) {
      return _cachedToken;
    }

    // 2. Persistent storage
    final storedToken  = await _storage.read(key: _storageKeyToken);
    final storedExpiry = await _storage.read(key: _storageKeyExpiry);
    if (storedToken != null && storedExpiry != null) {
      final expiry = DateTime.tryParse(storedExpiry);
      if (expiry != null &&
          DateTime.now().isBefore(expiry.subtract(_expiryBuffer))) {
        _cachedToken  = storedToken;
        _tokenExpiry  = expiry;
        return _cachedToken;
      }
    }

    // 3. Fetch new token from Medplum
    return _fetchNewToken();
  }

  /// Clears the in-memory cache and persisted token.
  Future<void> clearToken() async {
    _cachedToken = null;
    _tokenExpiry = null;
    await _storage.delete(key: _storageKeyToken);
    await _storage.delete(key: _storageKeyExpiry);
  }

  /// Returns true when a network interface other than none is active.
  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<String?> _fetchNewToken() async {
    try {
      final response = await _client.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type':    'client_credentials',
          'client_id':     _clientId,
          'client_secret': _clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final json       = jsonDecode(response.body) as Map<String, dynamic>;
        final token      = json['access_token'] as String?;
        final expiresIn  = (json['expires_in'] as num?)?.toInt() ?? 3600;

        if (token == null || token.isEmpty) {
          debugPrint('MedplumAuthService: access_token absent in 200 response');
          return null;
        }

        final expiry = DateTime.now().add(Duration(seconds: expiresIn));

        // Persist
        await _storage.write(key: _storageKeyToken,  value: token);
        await _storage.write(key: _storageKeyExpiry, value: expiry.toIso8601String());

        // Cache in memory
        _cachedToken = token;
        _tokenExpiry = expiry;

        debugPrint('MedplumAuthService: token fetched successfully');
        return token;
      } else {
        debugPrint(
            'MedplumAuthService: token fetch failed '
            '${response.statusCode} — ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('MedplumAuthService._fetchNewToken error: $e');
      return null;
    }
  }
}
