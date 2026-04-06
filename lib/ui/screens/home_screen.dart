// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/providers/app_navigation_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(medicalSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TeleMed_K'),
        actions: [
          AccessibleTouchTarget(
            semanticLabel: 'Schimbă Limba / Change Language',
            onTap: () {}, // Future toggle implementation
            child: const Text('RO/EN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          AccessibleTouchTarget(
            semanticLabel: 'Deschide Camera',
            onTap: () {
              ref.read(medicalSessionProvider.notifier).startRecording();
              
              // Mocking a multimodal processing flow wait
              Future.delayed(const Duration(seconds: 1), () {
                final dummyMedia = File('dummy_multimodal_path.jpg');
                ref.read(medicalSessionProvider.notifier).processMedia(dummyMedia);
              });
            },
            child: const Icon(Icons.camera_alt, size: 32),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (sessionState == SessionState.processing)
                const CircularProgressIndicator(color: AppTheme.textPrimary)
              else
                Flexible(
                  child: AccessibleTouchTarget(
                    semanticLabel: 'Apasă pentru a vorbi cu asistentul',
                    onTap: () {
                      ref.read(medicalSessionProvider.notifier).startRecording();
                      
                      // Mocking an audio processing flow wait
                      Future.delayed(const Duration(seconds: 1), () {
                        final dummyAudio = File('dummy_voice_path.wav');
                        ref.read(medicalSessionProvider.notifier).processAudio(dummyAudio);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(60.0),
                      child: const Icon(Icons.mic, size: 120.0, color: Colors.red),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              const Text(
                'Apasă și vorbește',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.backgroundLight,
        selectedItemColor: AppTheme.textPrimary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 18,
        unselectedFontSize: 18,
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.history);
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
}
