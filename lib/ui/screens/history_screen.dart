// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/providers/patient_history_provider.dart';
import '../theme/theme.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/dialog_detail_sheet.dart';
import '../widgets/language_toggle.dart';
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
        actions: const [
          LanguageToggle(),
          SizedBox(width: 16),
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
                        final String dateStr = DateFormatter.format(isoDate, includeTime: true);
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
                              onTap: () => DialogDetailSheet.show(
                                context,
                                ref,
                                lang,
                                item,
                                dateStr,
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


  String _getFallbackText(Map<String, dynamic> item) {
    if (item['resourceType'] == 'Observation') return 'Observație Medicală';
    if (item['resourceType'] == 'Condition') return 'Condiție Medicală';
    return 'Înregistrare Medicală';
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
