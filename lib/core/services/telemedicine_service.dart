// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TelemedicineService {
  static const MethodChannel _channel = MethodChannel('com.telemed_k/telemedicine');

  /// Captures the FCM token securely for direct Medplum FHIR backend communication.
  Future<String?> captureFcmToken() async {
    try {
      final String? token = await _channel.invokeMethod<String>('getFcmToken');
      // In a real app, this token would be synced directly to the Medplum FHIR Backend
      // without passing through unencrypted proxy servers to protect PHI.
      return token;
    } on PlatformException catch (e) {
      throw Exception('Failed to get FCM token securely: ${e.code}');
    }
  }

  /// Listens for incoming WebRTC call from Medplum.
  Future<void> listenForIncomingCall(Function(Map<String, dynamic>) onCallReceived) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIncomingCall') {
        onCallReceived(Map<String, dynamic>.from(call.arguments));
      }
    });
  }

  /// Answers the WebRTC video stream securely.
  Future<void> answerCall(String callId) async {
    try {
      await _channel.invokeMethod('answerCall', {'callId': callId});
    } on PlatformException catch (e) {
      throw Exception('Failed to securely answer call: ${e.code}');
    }
  }
}

final telemedicineServiceProvider = Provider<TelemedicineService>((ref) {
  return TelemedicineService();
});
