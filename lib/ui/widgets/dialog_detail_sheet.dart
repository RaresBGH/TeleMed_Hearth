// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/chat_message.dart';
import '../../core/providers/medplum_auth_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/utils/fhir_extension_utils.dart';
import '../screens/medical_response_screen.dart';

/// Shared bottom sheet used by HistoryScreen and DashboardScreen to display
/// a saved FHIR Observation's conversation and AI response.
class DialogDetailSheet {
  DialogDetailSheet._();

  static void show(
    BuildContext context,
    WidgetRef ref,
    String lang,
    Map<String, dynamic> item,
    String dateStr,
    String? status, {
    int? dialogueNumber,
  }) {
    final valueString = item['valueString'] as String?;
    final noteList    = item['note'] as List?;
    final noteText    = noteList?.isNotEmpty == true
        ? ((noteList!.first as Map?)?['text'] as String?)
        : null;

    // Doctor-reviewed lock: check for the exact reviewed-by extension URL
    // (NOT reviewed-by-target, which is written by the patient on every finalize).
    // Also respect status=='final' for backwards compat.
    final extensions = item['extension'] as List? ?? const [];
    final reviewedByDr = extensions.any(
      (e) => (e['url'] as String? ?? '') == FhirExtensionUtils.reviewedByUrl,
    );
    final isLocked = status == 'final' || reviewedByDr;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => _DialogDetailSheetBody(
          item: item,
          dateStr: dateStr,
          status: status,
          dialogueNumber: dialogueNumber,
          lang: lang,
          scrollController: scrollCtrl,
          valueString: valueString,
          noteText: noteText,
          isLocked: isLocked,
          outerContext: context,
        ),
      ),
    );
  }
}

// ── Private stateful body — ConsumerStatefulWidget for async doctor follow-up ──

class _DialogDetailSheetBody extends ConsumerStatefulWidget {
  const _DialogDetailSheetBody({
    required this.item,
    required this.dateStr,
    this.status,
    this.dialogueNumber,
    required this.lang,
    required this.scrollController,
    this.valueString,
    this.noteText,
    required this.isLocked,
    required this.outerContext,
  });

  final Map<String, dynamic> item;
  final String dateStr;
  final String? status;
  final int? dialogueNumber;
  final String lang;
  final ScrollController scrollController;
  final String? valueString;
  final String? noteText;
  final bool isLocked;
  final BuildContext outerContext;

  @override
  ConsumerState<_DialogDetailSheetBody> createState() =>
      _DialogDetailSheetBodyState();
}

class _DialogDetailSheetBodyState
    extends ConsumerState<_DialogDetailSheetBody> {
  bool _followupLoading = true;
  List<Map<String, dynamic>> _followupMessages = [];

  @override
  void initState() {
    super.initState();
    _loadDoctorFollowup();
  }

  Future<void> _loadDoctorFollowup() async {
    final subjectRef =
        widget.item['subject']?['reference'] as String?;
    final patientId =
        (subjectRef?.startsWith('Patient/') == true)
            ? subjectRef!.substring('Patient/'.length)
            : null;
    final obsId = widget.item['id'] as String?;

    if (patientId == null || obsId == null || obsId.isEmpty) {
      if (mounted) setState(() => _followupLoading = false);
      return;
    }

    try {
      final comms = await ref.read(medplumRepositoryProvider).getCommunications(
        patientId,
        aboutReference: 'Observation/$obsId',
      );

      // Filter: doctor-authored text-only Communications.
      // Attachments are intentionally skipped — use Continue Conversation for those.
      // Synthetic AI announcement bubble is intentionally NOT injected here.
      final doctorText = comms.where((c) {
        final exts = (c['extension'] as List?) ?? [];
        final isPatient = exts.any((e) =>
            (e['url'] == FhirExtensionUtils.isPatientUrl ||
                e['url'] == 'isPatient') &&
            e['valueBoolean'] == true);
        if (isPatient) return false;
        final payloadList = (c['payload'] as List?) ?? [];
        final text =
            (payloadList.firstOrNull as Map?)?['contentString'] as String?;
        if (text == null || text.trim().isEmpty) return false;
        // Skip if any payload entry carries an attachment.
        if (payloadList.any((p) =>
            (p as Map?)?.containsKey('contentAttachment') == true)) return false;
        return true;
      }).toList();

      // Sort by sent ascending; Communications without a sent timestamp go last.
      doctorText.sort((a, b) {
        final aS = a['sent'] as String? ?? '';
        final bS = b['sent'] as String? ?? '';
        if (aS.isEmpty && bS.isEmpty) return 0;
        if (aS.isEmpty) return 1;
        if (bS.isEmpty) return -1;
        return aS.compareTo(bS);
      });

      if (mounted) {
        setState(() {
          _followupMessages = doctorText;
          _followupLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DialogDetailSheet: doctor follow-up fetch failed: $e');
      if (mounted) setState(() => _followupLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang           = widget.lang;
    final item           = widget.item;
    final dateStr        = widget.dateStr;
    final status         = widget.status;
    final dialogueNumber = widget.dialogueNumber;
    final valueString    = widget.valueString;
    final noteText       = widget.noteText;
    final isLocked       = widget.isLocked;
    final scrollCtrl     = widget.scrollController;

    // ── Follow-up section widget (rendered inside the ListView) ──────────────
    Widget followupSection() {
      if (_followupLoading) {
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: Row(
            children: [
              Text(
                AppStrings.of(lang, 'dossier.followup_section_title'),
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF5BA4CF),
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF5BA4CF)),
              ),
            ],
          ),
        );
      }
      if (_followupMessages.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            AppStrings.of(lang, 'dossier.followup_section_title'),
            style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: Color(0xFF5BA4CF),
            ),
          ),
          const SizedBox(height: 10),
          ..._followupMessages.map((c) {
            final payloadList = (c['payload'] as List?) ?? [];
            final text =
                (payloadList.firstOrNull as Map?)?['contentString'] as String? ??
                    '';
            // Doctor bubble — replicates _buildBubble doctor branch from
            // medical_response_screen.dart lines 1387–1418.
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7EE),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppStrings.of(lang, 'role.doctor'),
                          style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: Color(0xFF1A6A3A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1C1C), height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dialogueNumber != null
                            ? AppStrings.of(lang, 'history.dialogue_header')
                                .replaceAll('{n}', dialogueNumber.toString()) +
                              ' — ' + dateStr
                            : dateStr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(builder: (_) {
                      final isPrelim = status == 'preliminary';
                      final lbl = isPrelim
                          ? AppStrings.of(lang, 'history.dialog_saved')
                          : status == 'final'
                              ? AppStrings.of(lang, 'history.triage_ai')
                              : AppStrings.of(lang, 'history.report');
                      final bg = isPrelim
                          ? const Color(0xFFE3F2FD)
                          : const Color(0x1A5BA4CF);
                      final fg = isPrelim
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF5BA4CF);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          lbl,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: fg,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (valueString != null && valueString.isNotEmpty) ...[
                      Text(
                        AppStrings.of(lang, 'history.summary_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5BA4CF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: const Border(
                            left: BorderSide(color: Color(0xFF5BA4CF), width: 4),
                          ),
                        ),
                        child: Text(
                          valueString,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (noteText != null && noteText.isNotEmpty) ...[
                      Text(
                        AppStrings.of(lang, 'history.conv_label'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5BA4CF),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...noteText
                          .trim()
                          .split('\n')
                          .where((l) => l.trim().isNotEmpty)
                          .map((line) {
                        final isAi = line.startsWith('[AI]');
                        final rawText = line
                            .replaceFirst(
                                RegExp(r'^\[(AI|Pacient|Patient)\]\s*\d+:\d+:\s*'), '')
                            .trim();
                        if (rawText.isEmpty) return const SizedBox.shrink();
                        // Replace raw file path markers with human-readable labels.
                        final displayText = rawText.startsWith('[Voice:')
                            ? AppStrings.of(lang, 'chat.voice_bubble')
                            : rawText.startsWith('[Photo:')
                                ? AppStrings.of(lang, 'chat.photo_bubble')
                                : rawText;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Align(
                            alignment: isAi
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.78,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isAi
                                      ? const Color(0x1A5BA4CF)
                                      : const Color(0xFF5BA4CF),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(isAi ? 4 : 16),
                                    bottomRight:
                                        Radius.circular(isAi ? 16 : 4),
                                  ),
                                ),
                                child: Text(
                                  displayText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    color: isAi
                                        ? const Color(0xFF191C1F)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                    if ((valueString == null || valueString.isEmpty) &&
                        (noteText == null || noteText.isEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Center(
                          child: Text(
                            AppStrings.of(lang, 'history.no_content'),
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    followupSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Bottom action: continue (not locked) or locked notice (doctor-reviewed / final)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: isLocked
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline,
                                color: Color(0xFF40484E), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppStrings.of(lang, 'dossier.consultation_locked'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF40484E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text(
                            AppStrings.of(lang, 'history.continue_btn'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5BA4CF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(widget.outerContext).pop();
                            try {
                              final messages =
                                  _parseNoteToMessages(noteText ?? '');
                              final obsId = item['id'] as String?;
                              // Navigator.push bypasses the flat-nav session guard.
                              // Pass observationId + existingObservation to activate
                              // Area 1 re-join mode (loads doctor Communications).
                              Navigator.push(
                                widget.outerContext,
                                MaterialPageRoute(
                                  builder: (_) => MedicalResponseScreen(
                                    initialResponse: valueString ?? '',
                                    isEmergency: false,
                                    initialMessages: messages,
                                    observationId: (obsId != null && obsId.isNotEmpty)
                                        ? obsId
                                        : null,
                                    existingObservation: item,
                                  ),
                                ),
                              );
                              // Persist observationId so finalizeConsultation calls
                              // updateObservation (not saveObservation).
                              if (obsId != null && obsId.isNotEmpty) {
                                ref
                                    .read(medicalSessionProvider.notifier)
                                    .prepareResume(
                                      aiResponse: valueString ?? '',
                                      messages: messages,
                                      existingObservationId: obsId,
                                    );
                              }
                            } catch (e) {
                              debugPrint(
                                  'DialogDetailSheet: continue conversation error: $e');
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
    );
  }

  static List<ChatMessage> _parseNoteToMessages(String noteText) {
    if (noteText.trim().isEmpty) return [];
    return noteText
        .trim()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((line) {
          final isAi = line.startsWith('[AI]');
          final text = line
              .replaceFirst(
                  RegExp(r'^\[(AI|Pacient|Patient)\]\s*\d+:\d+:\s*'), '')
              .trim();
          if (text.isEmpty) return null;

          // Reconstruct attachment markers embedded during finalizeConsultation.
          if (!isAi && text.startsWith('[Voice:') && text.endsWith(']')) {
            final path = text.substring('[Voice:'.length, text.length - 1);
            return ChatMessage(
              role: 'patient',
              text: '[Voice message]',
              timestamp: DateTime.now(),
              attachmentType: AttachmentType.audio,
              attachmentPath: path.isEmpty ? null : path,
            );
          }
          if (!isAi && text.startsWith('[Photo:') && text.endsWith(']')) {
            final path = text.substring('[Photo:'.length, text.length - 1);
            return ChatMessage(
              role: 'patient',
              text: '[Photo]',
              timestamp: DateTime.now(),
              attachmentType: AttachmentType.image,
              attachmentPath: path.isEmpty ? null : path,
            );
          }
          // Legacy markers saved before path encoding was introduced.
          if (!isAi && text == '[Voice message]') {
            return ChatMessage(
              role: 'patient',
              text: '[Voice message]',
              timestamp: DateTime.now(),
              attachmentType: AttachmentType.audio,
              attachmentPath: null,
            );
          }
          if (!isAi && text == '[Photo]') {
            return ChatMessage(
              role: 'patient',
              text: '[Photo]',
              timestamp: DateTime.now(),
              attachmentType: AttachmentType.image,
              attachmentPath: null,
            );
          }

          return ChatMessage(
            role: isAi ? 'ai' : 'patient',
            text: text,
            timestamp: DateTime.now(),
          );
        })
        .whereType<ChatMessage>()
        .toList();
  }
}
