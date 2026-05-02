// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/chat_message.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/medical_session_provider.dart';

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
    String? status,
  ) {
    final valueString = item['valueString'] as String?;
    final noteList    = item['note'] as List?;
    final noteText    = noteList?.isNotEmpty == true
        ? ((noteList!.first as Map?)?['text'] as String?)
        : null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Container(
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
                        dateStr,
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
                        AppStrings.of(lang, 'history.ai_label'),
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
                        final displayText = line
                            .replaceFirst(
                                RegExp(r'^\[(AI|Pacient)\]\s*\d+:\d+:\s*'), '')
                            .trim();
                        if (displayText.isEmpty) return const SizedBox.shrink();
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // "Continuă conversația" button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
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
                      Navigator.of(context).pop();
                      ref.read(medicalSessionProvider.notifier).prepareResume(
                        aiResponse: valueString ?? '',
                        messages: _parseNoteToMessages(noteText ?? ''),
                        existingObservationId: item['id'] as String?,
                      );
                      ref
                          .read(appNavigationProvider.notifier)
                          .navigateTo(AppRoute.medicalResponse);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
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
                  RegExp(r'^\[(AI|Pacient)\]\s*\d+:\d+:\s*'), '')
              .trim();
          if (text.isEmpty) return null;
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
