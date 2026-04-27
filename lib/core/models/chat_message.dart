// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

class ChatMessage {
  final String role; // 'ai' or 'patient'
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });
}
