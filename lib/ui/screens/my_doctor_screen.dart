// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/language_toggle.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/my_doctor_provider.dart';
import '../../core/services/telemedicine_service.dart';
import '../theme/theme.dart';

class MyDoctorScreen extends ConsumerStatefulWidget {
  const MyDoctorScreen({super.key});

  @override
  ConsumerState<MyDoctorScreen> createState() => _MyDoctorScreenState();
}

class _MyDoctorScreenState extends ConsumerState<MyDoctorScreen> {
  bool _isCallActive = false;

  @override
  void initState() {
    super.initState();
    _initializeTelemedicine();
  }

  Future<void> _initializeTelemedicine() async {
    final telemedicineService = ref.read(telemedicineServiceProvider);
    
    // 1. Capture FCM token for push notifications securely mapping to Medplum FHIR backend.
    try {
      await telemedicineService.captureFcmToken();
    } catch (e) {
      debugPrint("FCM Error: $e");
    }

    // 2. Listen for incoming WebRTC calls mimicking Medplum backend trigger
    telemedicineService.listenForIncomingCall((callData) {
      if (mounted) {
        setState(() {
          _isCallActive = true;
        });
      }
    });

    // Mock incoming call for demo purposes after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isCallActive) {
        setState(() {
          _isCallActive = true;
        });
      }
    });
  }

  void _showConsentAndAnswer() {
    // Navigates to waiting room for FCM listener replacement
    ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.waitingRoom);
  }

  @override
  Widget build(BuildContext context) {
    final encounterAsync = ref.watch(mostRecentEncounterProvider);
    final medAsync = ref.watch(mostRecentMedicationProvider);
    final String lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.account_circle, color: Color(0xFF5BA4CF), size: 36),
            const SizedBox(width: 8),
            Text(AppStrings.of(lang, 'doctor.screen_title'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Doctor Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF5BA4CF).withValues(alpha: 0.2), width: 4),
                      ),
                      child: const Center(
                        child: Icon(Icons.person, size: 80, color: Colors.grey),
                      ), // Placeholder for real image
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dr. Adriana Bogheanu',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Medic de Familie',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5BA4CF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF5BA4CF), size: 24),
                          const SizedBox(width: 8),
                          Text(AppStrings.of(lang, 'doctor.available'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5BA4CF))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Incoming Call Card
              if (_isCallActive)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF5BA4CF), width: 2),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.video_call, color: Color(0xFF5BA4CF), size: 48),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Apel Video de la Dr. Bogheanu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                                Text('Consultație programată', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AccessibleTouchTarget(
                        semanticLabel: 'Răspunde la apel',
                        onTap: () => _showConsentAndAnswer(),
                        child: Container(
                          width: double.infinity,
                          height: 96, // Large touch target
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5BA4CF), Color(0xFF4A93BE)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.call, color: Colors.white, size: 48),
                              const SizedBox(width: 16),
                              Text(AppStrings.of(lang, 'doctor.answer'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AccessibleTouchTarget(
                        semanticLabel: 'Respinge apelul',
                        onTap: () {
                          setState(() => _isCallActive = false);
                        },
                        child: Container(
                          width: double.infinity,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(AppStrings.of(lang, 'doctor.decline'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // Context Grid
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.schedule, color: Colors.black54, size: 36),
                          const SizedBox(height: 8),
                          Text(AppStrings.of(lang, 'doctor.last_visit'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 4),
                          encounterAsync.when(
                            data: (data) {
                              if (data == null) return const Text('Niciuna', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black));
                              return Text(data['period']?['start'] ?? 'Necunoscută', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black));
                            },
                            loading: () => const CircularProgressIndicator(color: Color(0xFF5BA4CF)),
                            error: (err, stack) => const Text('Eroare', style: TextStyle(fontSize: 22, color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.medication, color: Colors.black54, size: 36),
                          const SizedBox(height: 8),
                          Text(AppStrings.of(lang, 'doctor.prescription'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 4),
                          medAsync.when(
                            data: (data) {
                              if (data == null) return const Text('Niciuna', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black));
                              final text = data['medicationCodeableConcept']?['text'] ?? 'Tratament';
                              return Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black));
                            },
                            loading: () => const CircularProgressIndicator(color: Color(0xFF5BA4CF)),
                            error: (err, stack) => const Text('Eroare', style: TextStyle(fontSize: 22, color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48), // Padding for bottom nav
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
}
