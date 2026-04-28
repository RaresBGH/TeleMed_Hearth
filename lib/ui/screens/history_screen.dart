// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/chat_message.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/providers/patient_history_provider.dart';
import '../theme/theme.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../../core/l10n/app_strings.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(patientHistoryProvider);
    final String lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('TeleMed_K', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        actions: [
          AccessibleTouchTarget(
            semanticLabel: 'Schimbă Limba / Change Language',
            onTap: () {
              final newLang = lang == 'ro' ? 'en' : 'ro';
              ref.read(languageProvider.notifier).setLanguage(newLang);
              ref.read(aiEngineServiceProvider).setLanguage(newLang);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: lang == 'ro' ? const Color(0xFF5BA4CF) : Colors.black38,
                    fontSize: 18,
                  ),
                ),
                const Text(' / ', style: TextStyle(color: Colors.black38, fontSize: 18)),
                Text(
                  'EN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: lang == 'en' ? const Color(0xFF5BA4CF) : Colors.black38,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.of(lang, 'history.title'),
                style: const TextStyle(fontSize: 32, color: Colors.black, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.of(lang, 'history.subtitle'),
                style: const TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: historyAsync.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return Center(
                        child: Text(
                          AppStrings.of(lang, 'history.empty'),
                          style: const TextStyle(fontSize: 20, color: Colors.black),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final item = data[index];
                        final String isoDate =
                            item['effectiveDateTime'] as String? ??
                            item['recordedDate'] as String? ??
                            '';
                        final String dateStr = _formatDateTime(isoDate);
                        final code = item['code'] ?? {};
                        final String label =
                            code['text'] as String? ?? _getFallbackText(item);
                        final String? valueString =
                            item['valueString'] as String?;
                        final String? status = item['status'] as String?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: AccessibleTouchTarget(
                              semanticLabel: 'Deschide detalii raport',
                              onTap: () => _showDetailSheet(
                                context,
                                ref,
                                lang,
                                item,
                                dateStr,
                                label,
                                status,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                        _buildStatusBadge(status),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.medical_information,
                                            color: Color(0xFF5BA4CF), size: 28),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                label,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              if (valueString != null &&
                                                  valueString.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  valueString,
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF40484E),
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF5BA4CF))),
                  error: (err, stack) => const Center(
                    child: Text(
                      'Eroare la încărcarea istoricului.',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
          ),
          const AppBottomNavBar(),
        ],
      ),
    );
  }

  static void _showDetailSheet(
    BuildContext context,
    WidgetRef ref,
    String lang,
    Map<String, dynamic> item,
    String dateStr,
    String label,
    String? status,
  ) {
    final String? valueString = item['valueString'] as String?;
    final noteList = item['note'] as List?;
    final String? noteText = noteList?.isNotEmpty == true
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
              // Header
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
                    // inline badge — avoids referencing instance method from static
                    Builder(builder: (_) {
                      final bool isPrelim = status == 'preliminary';
                      final String lbl = isPrelim
                          ? 'Dialog Salvat'
                          : status == 'final'
                              ? 'Triaj AI'
                              : 'Raport';
                      final Color bg = isPrelim
                          ? const Color(0xFFE3F2FD)
                          : const Color(0x1A5BA4CF);
                      final Color fg = isPrelim
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF5BA4CF);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(lbl,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: fg)),
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
                    // AI triage summary
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
                            left: BorderSide(
                                color: Color(0xFF5BA4CF), width: 4),
                          ),
                        ),
                        child: Text(
                          valueString,
                          style: const TextStyle(
                              fontSize: 16, height: 1.5, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Conversation log
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
                        final bool isAi = line.startsWith('[AI]');
                        // Strip prefix like "[AI] 10:30: " or "[Pacient] 10:31: "
                        final String displayText = line
                            .replaceFirst(
                                RegExp(r'^\[(AI|Pacient)\]\s*\d+:\d+:\s*'),
                                '')
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
                    // Empty state
                    if ((valueString == null || valueString.isEmpty) &&
                        (noteText == null || noteText.isEmpty))
                      const Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Center(
                          child: Text(
                            'Nu există conținut detaliat pentru acest raport.',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // ── "Continuă conversația" button ─────────────────────────────
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

  /// Parses a saved note string (lines like "[AI] HH:mm: text") into a
  /// list of ChatMessage objects for pre-populating the resumed chat.
  static List<ChatMessage> _parseNoteToMessages(String noteText) {
    if (noteText.trim().isEmpty) return [];
    return noteText
        .trim()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((line) {
          final bool isAi = line.startsWith('[AI]');
          final String text = line
              .replaceFirst(RegExp(r'^\[(AI|Pacient)\]\s*\d+:\d+:\s*'), '')
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

  String _getFallbackText(Map<String, dynamic> item) {
    if (item['resourceType'] == 'Observation') return 'Observație Medicală';
    if (item['resourceType'] == 'Condition') return 'Condiție Medicală';
    return 'Înregistrare Medicală';
  }

  /// Parses an ISO 8601 datetime string and returns "DD.MM.YYYY HH:mm".
  /// Falls back to the raw string or a placeholder if parsing fails.
  String _formatDateTime(String isoString) {
    if (isoString.isEmpty) return 'Dată recentă';
    final DateTime? dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final String day   = dt.day.toString().padLeft(2, '0');
    final String month = dt.month.toString().padLeft(2, '0');
    final String hour  = dt.hour.toString().padLeft(2, '0');
    final String min   = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year}  $hour:$min';
  }

  /// Status-aware badge.
  /// • preliminary → blue  "Dialog Salvat"
  /// • final       → blue  "Triaj AI"
  /// • anything else       "Raport"
  Widget _buildStatusBadge(String? status) {
    final bool isPreliminary = status == 'preliminary';
    final String label = isPreliminary
        ? 'Dialog Salvat'
        : status == 'final'
            ? 'Triaj AI'
            : 'Raport';
    final Color bg    = isPreliminary
        ? const Color(0xFFE3F2FD)
        : const Color(0xFF5BA4CF).withValues(alpha: 0.10);
    final Color fg    = isPreliminary
        ? const Color(0xFF1565C0)
        : const Color(0xFF5BA4CF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
