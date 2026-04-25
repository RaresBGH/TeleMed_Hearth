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
                        final dateStr = item['effectiveDateTime'] ?? item['recordedDate'] ?? 'Dată recentă';
                        final code = item['code'] ?? {};
                        final text = code['text'] ?? _getFallbackText(item);

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
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            dateStr,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF5BA4CF).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'Raport Trimis',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF5BA4CF),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Icon(Icons.medical_information, color: Color(0xFF5BA4CF), size: 32),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            text,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Colors.black,
                                            ),
                                          ),
                                        )
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
}
