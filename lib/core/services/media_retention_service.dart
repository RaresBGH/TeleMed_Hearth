// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service overseeing heavy media uploads and local retention policies.
/// Ensures large files don't exhaust device storage for seniors.
class MediaRetentionService {
  static const String _medplumBaseUrl = 'https://api.medplum.com/fhir/R4';

  /// Uploads heavy triage media securely to Medplum FHIR backend
  /// as a Binary resource, returning a structured Media FHIR Resource.
  /// 
  /// Requires the Medplum OAuth2 [bearerToken].
  Future<Map<String, dynamic>?> uploadMediaToCloud(File mediaFile, String contentType, String bearerToken) async {
    try {
      final fileBytes = await mediaFile.readAsBytes();

      // Step 1: Upload the raw binary stream to create a FHIR Binary resource
      final binaryResponse = await http.post(
        Uri.parse('$_medplumBaseUrl/Binary'),
        headers: {
          'Content-Type': contentType,
          'Authorization': 'Bearer $bearerToken',
        },
        body: fileBytes,
      );

      if (binaryResponse.statusCode != 200 && binaryResponse.statusCode != 201) {
        debugPrint('Media Binary Upload Failed: ${binaryResponse.statusCode}');
        return null;
      }

      final binaryData = jsonDecode(binaryResponse.body);
      final binaryId = binaryData['id'];

      if (binaryId == null) return null;

      // Step 2: Formulate and push the structured Media FHIR Resource
      final mediaResource = {
        'resourceType': 'Media',
        'status': 'completed',
        'content': {
          'contentType': contentType,
          'url': 'Binary/$binaryId',
        }
      };

      final mediaResponse = await http.post(
        Uri.parse('$_medplumBaseUrl/Media'),
        headers: {
          'Content-Type': 'application/fhir+json',
          'Authorization': 'Bearer $bearerToken',
        },
        body: jsonEncode(mediaResource),
      );

      if (mediaResponse.statusCode == 200 || mediaResponse.statusCode == 201) {
        return jsonDecode(mediaResponse.body);
      } else {
        debugPrint('Media Resource Link Failed: ${mediaResponse.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Secure Upload Transport Exception');
      return null;
    }
  }

  /// Scans the local application media directory and executes 
  /// the 14-Day Physical Deletion Rule to prevent local hardware bloat.
  Future<void> executeGarbageCollection() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Specifically target a custom AI-triage media sub-directory if it exists,
      // or scan the docs root based on physical file metadata.
      final mediaDir = Directory('${directory.path}/ai_triage_media');
      
      if (!mediaDir.existsSync()) {
        return; // Nothing to clean
      }

      final thresholdDate = DateTime.now().subtract(const Duration(days: 14));
      
      final entities = mediaDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final stats = entity.statSync();
          if (stats.modified.isBefore(thresholdDate)) {
            entity.deleteSync();
            debugPrint('Executed 14-Day Physical Deletion Rule on archaic artifact.');
          }
        }
      }
    } catch (e) {
      debugPrint('Secure Garbage Collection Interrupted');
    }
  }
}

final mediaRetentionServiceProvider = Provider<MediaRetentionService>((ref) {
  return MediaRetentionService();
});
