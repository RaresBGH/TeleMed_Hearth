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
import '../../core/services/audio_recording_service.dart';
import '../../core/services/camera_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isRecording = false;

  Future<void> _onCameraTap() async {
    final cameraService = ref.read(cameraServiceProvider);

    final hasPermission = await cameraService.requestPermission();
    if (!mounted) return;

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permisiunea pentru cameră este necesară.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
      return;
    }

    final imagePath = await cameraService.captureImage();
    if (!mounted) return;

    if (imagePath == null) return; // user cancelled

    // processMedia sets sessionState to processing → spinner appears in body
    await ref
        .read(medicalSessionProvider.notifier)
        .processMedia(File(imagePath));

    // Delete the temp JPEG after inference; compressed AAC/video handled separately
    cameraService.deleteTempFile(imagePath);
  }

  Future<void> _onMicTap() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    if (_isRecording) {
      // ── Stop recording, hand WAV to inference ──────────────────────────
      final wavPath = await audioService.stopRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);

      if (wavPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eroare la oprirea înregistrării.',
                style: TextStyle(fontSize: 18)),
          ),
        );
        return;
      }

      // processAudio sets state to processing → success / emergency / error
      await ref
          .read(medicalSessionProvider.notifier)
          .processAudio(File(wavPath));

      // Delete WAV after inference; AAC transcode has already been kicked off
      // asynchronously inside stopRecording(), so the WAV is no longer needed.
      audioService.deleteWavFile(wavPath);
    } else {
      // ── Request permission then start recording ────────────────────────
      final hasPermission = await audioService.requestPermission();
      if (!mounted) return;

      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permisiunea pentru microfon este necesară.',
              style: TextStyle(fontSize: 18),
            ),
          ),
        );
        return;
      }

      try {
        await audioService.startRecording();
        if (!mounted) return;
        setState(() => _isRecording = true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nu s-a putut porni înregistrarea: $e',
                style: const TextStyle(fontSize: 18)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(medicalSessionProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('TeleMed_K'),
        actions: [
          AccessibleTouchTarget(
            semanticLabel: 'Schimbă Limba / Change Language',
            onTap: () {}, // Future toggle implementation
            child: const Text('RO/EN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          AccessibleTouchTarget(
            semanticLabel: 'Deschide Camera',
            onTap: () { _onCameraTap(); },
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
                    semanticLabel: _isRecording
                        ? 'Apasă pentru a opri înregistrarea'
                        : 'Apasă pentru a vorbi cu asistentul',
                    onTap: _onMicTap,
                    child: Container(
                      decoration: BoxDecoration(
                        // Solid red while recording, light red when idle
                        color: _isRecording
                            ? Colors.red
                            : Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(60.0),
                      child: Icon(
                        // Stop icon while recording, mic icon when idle
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 120.0,
                        color: _isRecording ? Colors.white : Colors.red,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              Text(
                _isRecording ? 'Apasă pentru a opri' : 'Apasă și vorbește',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
