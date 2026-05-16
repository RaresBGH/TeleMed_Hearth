// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

/// Type of media attached to a [ChatMessage].
enum AttachmentType { image, pdf, audio, document }

class ChatMessage {
  final String role; // values: 'ai', 'patient', 'doctor'
  final String text;
  final DateTime timestamp;
  /// Local file path of an attached image, PDF, or audio file.
  final String? attachmentPath;
  /// Media type of the attachment; null for plain text messages.
  final AttachmentType? attachmentType;
  /// Resolved display name of the sender (used for role == 'doctor' bubbles).
  final String? senderName;
  /// True for AI error-fallback messages (e.g. photo analysis failure).
  /// These are shown in the UI but excluded from AI context and clinical summaries.
  final bool isErrorFallback;
  /// True for synthetic AI announcement messages injected client-side (e.g. the
  /// doctor-presence acknowledgment in re-join mode). Never saved to Medplum or
  /// included in the AI's conversation-history context.
  final bool isSyntheticAnnouncement;

  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.attachmentPath,
    this.attachmentType,
    this.senderName,
    this.isErrorFallback = false,
    this.isSyntheticAnnouncement = false,
  });
}
