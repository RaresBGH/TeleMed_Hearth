// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/patient_history_provider.dart';
import '../theme/theme.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(patientHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('TeleMed_K', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        actions: [
          AccessibleTouchTarget(
            semanticLabel: 'Schimbă Limba / Change Language',
            onTap: () {},
            child: const Text('RO/EN', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5BA4CF), fontSize: 18)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dosar Medical',
                style: TextStyle(fontSize: 32, color: Colors.black, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Consultați rapoartele trimise anterior.',
                style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: historyAsync.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nu există istoric medical.',
                          style: TextStyle(fontSize: 20, color: Colors.black),
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
                              onTap: () {},
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
                  error: (err, stack) => Center(
                    child: Text(
                      'Eroare la încărcarea istoricului.',
                      style: const TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF5BA4CF),
        unselectedItemColor: Colors.black,
        selectedFontSize: 18,
        unselectedFontSize: 18,
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.home);
          } else if (index == 2) {
            ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.myDoctor);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home, size: 36), label: 'Acasă'),
          BottomNavigationBarItem(icon: Icon(Icons.history, size: 36), label: 'Istoric'),
          BottomNavigationBarItem(icon: Icon(Icons.person, size: 36), label: 'Doctorul Meu'),
        ],
      ),
    );
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
