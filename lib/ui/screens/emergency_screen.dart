// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme.dart';
import '../../core/providers/medical_session_provider.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 120, color: Colors.red),
              const SizedBox(height: 48),
              const Text(
                'Urgență Medicală Detectată!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Apelăm 112 în 10 secunde...',
                style: TextStyle(fontSize: 24, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              AccessibleTouchTarget(
                semanticLabel: 'Suna acum la 112',
                onTap: () async {
                  final uri = Uri(scheme: 'tel', path: '112');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'SUNĂ ACUM',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // CRITICAL OVERRIDE: 2px solid black border implemented
              AccessibleTouchTarget(
                semanticLabel: 'Anulează apelul de urgență',
                onTap: () {
                  ref.read(medicalSessionProvider.notifier).reset();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2.0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Nu, anulează',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
