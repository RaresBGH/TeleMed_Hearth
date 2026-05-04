// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

/// Type of media attached to a [ChatMessage].
enum AttachmentType { image, pdf, audio }

class ChatMessage {
  final String role; // 'ai' or 'patient'
  final String text;
  final DateTime timestamp;
  /// Local file path of an attached image, PDF, or audio file.
  final String? attachmentPath;
  /// Media type of the attachment; null for plain text messages.
  final AttachmentType? attachmentType;

  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.attachmentPath,
    this.attachmentType,
  });
}
