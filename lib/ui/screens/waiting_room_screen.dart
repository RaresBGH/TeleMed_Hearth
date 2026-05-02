// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/services/telemedicine_service.dart';
import '../theme/theme.dart';

class WaitingRoomScreen extends ConsumerWidget {
  final String callId;

  const WaitingRoomScreen({super.key, this.callId = 'pending-encounter'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E2E2), 
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.of(lang, 'waiting.clinic'), style: const TextStyle(fontSize: 16, color: Colors.black54)),
                Text(AppStrings.of(lang, 'doctor.name'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            )
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Status Message Section
              Text(
                AppStrings.of(lang, 'waiting.connecting'),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black, height: 1.2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF5BA4CF).withValues(alpha: 0.4), shape: BoxShape.circle)),
                   const SizedBox(width: 8),
                   Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF5BA4CF).withValues(alpha: 0.7), shape: BoxShape.circle)),
                   const SizedBox(width: 8),
                   Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF5BA4CF), shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(height: 48),

              // Digital Consent Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: const Border(left: BorderSide(color: Color(0xFF5BA4CF), width: 8)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel, color: Color(0xFF5BA4CF), size: 36),
                        const SizedBox(width: 16),
                        Expanded(child: Text(AppStrings.of(lang, 'waiting.consent_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Prin acest serviciu, sunteți de acord cu partajarea datelor medicale cu Dr. Bogheanu pentru consultanță de la distanță.',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                    const SizedBox(height: 16),
                    _buildListItem('Acces securizat la istoricul dumneavoastră medical.'),
                    const SizedBox(height: 12),
                    _buildListItem('Înregistrarea sesiunii pentru acuratețe clinică.'),
                    const SizedBox(height: 12),
                    _buildListItem('Confidențialitate garantată prin protocol medical.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Ambient Instruction
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info, color: Colors.black),
                    const SizedBox(width: 12),
                    Expanded(child: Text(AppStrings.of(lang, 'waiting.info'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AccessibleTouchTarget(
                semanticLabel: 'Sunt de acord cu consultanța',
                onTap: () async {
                  try {
                    final fhirRepo = ref.read(fhirRepositoryProvider);
                    await fhirRepo.updateEncounterConsent(callId);
                    
                    await ref.read(telemedicineServiceProvider).answerCall(callId);
                    
                    if (!context.mounted) return;
                    ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.videoConsultation);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${AppStrings.of(lang, 'waiting.conn_error')} $e', style: const TextStyle(fontSize: 18))),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5BA4CF),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppStrings.of(lang, 'waiting.agree_btn'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 16),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 32),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AccessibleTouchTarget(
                semanticLabel: 'Anulează apelul',
                onTap: () {
                  ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.home);
                },
                child: Container(
                  width: double.infinity,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.close, color: Color(0xFFAB1118), size: 28),
                      const SizedBox(width: 16),
                      Text(AppStrings.of(lang, 'waiting.cancel_btn'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFAB1118), letterSpacing: 1.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.of(lang, 'waiting.note'),
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF4A93BE), size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 18, color: Colors.black))),
      ],
    );
  }
}
