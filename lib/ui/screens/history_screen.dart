// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_formatter.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/patient_history_provider.dart';
import '../theme/theme.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/dialog_detail_sheet.dart';
import '../widgets/language_toggle.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/fhir_extension_utils.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // patientHistoryProvider is invalidated by finalizeConsultation() in
    // MedicalSessionNotifier — after the FHIR write completes, not on idle
    // transition (which could fire before the write finishes).
    final historyAsync = ref.watch(patientHistoryProvider);
    final String lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(AppStrings.appName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
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
                        // Observation entries are always triage dialogs — use the
                        // translated AppStrings key so the label reacts to RO/EN toggle.
                        final String label =
                            item['resourceType'] == 'Observation'
                                ? AppStrings.of(lang, 'dashboard.triage_dialog')
                                : (code['text'] as String? ?? _getFallbackText(item, lang));
                        final String? valueString =
                            item['valueString'] as String?;
                        final String? status = item['status'] as String?;

                        // Extract doctorName and category from FHIR extensions.
                        final extensions =
                            (item['extension'] as List?) ?? const [];
                        String? doctorName;
                        String? category;
                        for (final ext in extensions) {
                          final e = ext as Map<String, dynamic>;
                          final url = e['url'] as String? ?? '';
                          if (FhirExtensionUtils.isDoctorName(url)) {
                            doctorName = e['valueString'] as String?;
                          } else if (FhirExtensionUtils.isSessionCategory(url)) {
                            category = e['valueString'] as String?;
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: AccessibleTouchTarget(
                              semanticLabel: AppStrings.of(lang, 'history.open_details'),
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
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dateStr,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              if (doctorName != null &&
                                                  doctorName.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${AppStrings.of(lang, 'history.doctor_attr')} $doctorName',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF5BA4CF),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            _buildStatusBadge(status, lang),
                                            if (category != null) ...[
                                              const SizedBox(height: 4),
                                              _buildCategoryChip(
                                                  category, lang),
                                            ],
                                          ],
                                        ),
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
                  error: (err, stack) => Center(
                    child: Text(
                      AppStrings.of(lang, 'history.error'),
                      style: const TextStyle(fontSize: 18, color: Colors.red),
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


  /// Color-coded chip for session category (BUG 7 fix).
  /// medical → #5BA4CF  |  document → #7B61FF (purple)  |  other → neutral gray
  Widget _buildCategoryChip(String category, String lang) {
    final Color bg;
    final Color fg;
    final String label;
    switch (category) {
      case 'medical':
        bg = const Color(0x1A5BA4CF);
        fg = const Color(0xFF5BA4CF);
        label = AppStrings.of(lang, 'history.cat_medical');
        break;
      case 'document':
        bg = const Color(0x1A7B61FF);
        fg = const Color(0xFF7B61FF);
        label = AppStrings.of(lang, 'history.cat_document');
        break;
      default: // 'other'
        bg = const Color(0xFFE6E8ED);
        fg = const Color(0xFF40484E);
        label = AppStrings.of(lang, 'history.cat_other');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  String _getFallbackText(Map<String, dynamic> item, String lang) {
    if (item['resourceType'] == 'Observation')
      return AppStrings.of(lang, 'history.fallback_observation');
    if (item['resourceType'] == 'Condition')
      return AppStrings.of(lang, 'history.fallback_condition');
    return AppStrings.of(lang, 'history.fallback_generic');
  }


  /// Status-aware badge.
  /// • preliminary → "Dialog Salvat" / "Saved Dialogue"
  /// • final       → "Triaj AI" / "AI Triage"
  /// • anything else → "Raport" / "Report"
  Widget _buildStatusBadge(String? status, String lang) {
    final bool isPreliminary = status == 'preliminary';
    final String label = isPreliminary
        ? AppStrings.of(lang, 'history.dialog_saved')
        : status == 'final'
            ? AppStrings.of(lang, 'history.triage_ai')
            : AppStrings.of(lang, 'history.report');
    final Color bg    = isPreliminary
        ? const Color(0xFFE3F2FD)
        : const Color(0xFF5BA4CF).withOpacity(0.10);
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
