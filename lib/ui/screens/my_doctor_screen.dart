// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';
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
  String _activeCallId = '';

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
          _activeCallId = callData['callId'] ?? 'medplum_video_call_id';
        });
      }
    });

    // Mock incoming call for demo purposes after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isCallActive) {
        setState(() {
          _isCallActive = true;
          _activeCallId = 'medplum_video_call_id';
        });
      }
    });
  }

  void _showConsentAndAnswer() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5F5F5), // High contrast off-white bg
          title: const Text(
            'Consimțământ Telemedicină',
            style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Sunteți de acord cu înregistrarea și procesarea datelor medicale conform normelor GD 1133/2022 pentru consultația video?',
            style: TextStyle(color: Colors.black, fontSize: 20),
          ),
          actions: [
            AccessibleTouchTarget(
              semanticLabel: 'Refuză apelul',
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _isCallActive = false);
              },
              child: const Text('REFUZ', style: TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            AccessibleTouchTarget(
              semanticLabel: 'Acceptă apelul video',
              onTap: () async {
                Navigator.of(context).pop(); // Close dialog
                try {
                  await ref.read(telemedicineServiceProvider).answerCall(_activeCallId);
                  if (!context.mounted) return;
                  setState(() => _isCallActive = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Consultație video conectată', style: TextStyle(fontSize: 18))),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Eroare conexiune: $e', style: const TextStyle(fontSize: 18))),
                  );
                }
              },
              child: const Text('ACCEPT', style: TextStyle(color: Color(0xFF0D631B), fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final encounterAsync = ref.watch(mostRecentEncounterProvider);
    final medAsync = ref.watch(mostRecentMedicationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_circle, color: Color(0xFF0D631B), size: 36),
            SizedBox(width: 8),
            Text('The Dignified Guardian', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        actions: [
          AccessibleTouchTarget(
            semanticLabel: 'Schimbă Limba / Change Language',
            onTap: () {},
            child: const Text('RO / EN', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D631B), fontSize: 18)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
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
                        border: Border.all(color: const Color(0xFF0D631B).withValues(alpha: 0.2), width: 4),
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
                        color: const Color(0xFF0D631B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF0D631B), size: 24),
                          SizedBox(width: 8),
                          Text('Disponibil acum', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D631B))),
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
                    border: Border.all(color: const Color(0xFF0D631B), width: 2),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.video_call, color: Color(0xFF0D631B), size: 48),
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
                              colors: [Color(0xFF0D631B), Color(0xFF2E7D32)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.call, color: Colors.white, size: 48),
                              SizedBox(width: 16),
                              Text('RĂSPUNDE', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
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
                          child: const Center(
                            child: Text('Respinge apelul', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
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
                          const Text('Ultima consultație', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 4),
                          encounterAsync.when(
                            data: (data) {
                              if (data == null) return const Text('Niciuna', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black));
                              return Text(data['period']?['start'] ?? 'Necunoscută', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black));
                            },
                            loading: () => const CircularProgressIndicator(color: Color(0xFF0D631B)),
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
                          const Text('Rețetă activă', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 4),
                          medAsync.when(
                            data: (data) {
                              if (data == null) return const Text('Niciuna', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black));
                              final text = data['medicationCodeableConcept']?['text'] ?? 'Tratament';
                              return Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black));
                            },
                            loading: () => const CircularProgressIndicator(color: Color(0xFF0D631B)),
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0D631B),
        unselectedItemColor: Colors.black,
        selectedFontSize: 18,
        unselectedFontSize: 18,
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.home);
          } else if (index == 1) {
            ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.history);
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
}
