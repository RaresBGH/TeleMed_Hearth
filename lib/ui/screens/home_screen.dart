// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/language_toggle.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/ai_ready_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/camera_service.dart';

// ── Design tokens (Stitch palette) ───────────────────────────────────────────
const Color _bg            = Color(0xFFF7F9FE); // surface-bright
const Color _surfaceCard   = Color(0xFFECEEF2); // surface-container
const Color _iconCircle    = Color(0xFFC6E7FF); // primary-fixed
const Color _iconColor     = Color(0xFF5BA4CF); // brand primary
const Color _titleColor    = Color(0xFF191C1F); // on-background
const Color _subtitleColor = Color(0xFF40484E); // on-surface-variant
const Color _errorRed      = Color(0xFFBA1A1A); // error / emergency

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isRecording = false;

  // ── Camera ─────────────────────────────────────────────────────────────────

  Future<void> _onCameraTap() async {
    final cameraService = ref.read(cameraServiceProvider);

    final hasPermission = await cameraService.requestPermission();
    if (!mounted) return;

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(ref.read(languageProvider), 'home.cam_no_perm'),
              style: const TextStyle(fontSize: 18)),
        ),
      );
      return;
    }

    final imagePath = await cameraService.captureImage();
    if (!mounted) return;
    if (imagePath == null) return;

    await ref
        .read(medicalSessionProvider.notifier)
        .processMedia(File(imagePath));
    cameraService.deleteTempFile(imagePath);
  }

  // ── Microphone ─────────────────────────────────────────────────────────────

  Future<void> _onMicTap() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    if (_isRecording) {
      final wavPath = await audioService.stopRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);

      if (wavPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(ref.read(languageProvider), 'home.mic_stop_error'),
                style: const TextStyle(fontSize: 18)),
          ),
        );
        return;
      }

      await ref
          .read(medicalSessionProvider.notifier)
          .processAudio(File(wavPath));
      audioService.deleteWavFile(wavPath);
    } else {
      final hasPermission = await audioService.requestPermission();
      if (!mounted) return;

      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(ref.read(languageProvider), 'home.mic_no_perm'),
                style: const TextStyle(fontSize: 18)),
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
            content: Text('${AppStrings.of(ref.read(languageProvider), 'home.mic_error')} $e',
                style: const TextStyle(fontSize: 18)),
          ),
        );
      }
    }
  }

  // ── Text triage ────────────────────────────────────────────────────────────

  void _showTextDialog(String lang) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(lang, 'home.dialog_title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: AppStrings.of(lang, 'home.dialog_hint'),
            hintStyle: const TextStyle(fontSize: 18),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.of(lang, 'home.dialog_cancel'),
                style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => _onTextSubmit(controller.text, ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _iconColor,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.of(lang, 'home.dialog_send'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _onTextSubmit(String text, BuildContext dialogCtx) async {
    if (text.trim().isEmpty) return;
    Navigator.of(dialogCtx).pop();
    await ref.read(medicalSessionProvider.notifier).processText(text.trim());
  }

  // ── Emergency ──────────────────────────────────────────────────────────────

  Future<void> _onEmergencyTap() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(medicalSessionProvider).sessionState;
    final patientName  = ref.watch(patientAuthProvider).patientFirstName;
    final lang         = ref.watch(languageProvider);
    final bool _aiReady = ref.watch(aiReadyProvider).maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'TeleMed_K',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Color(0xFF191C1F),
          ),
        ),
        actions: const [
          LanguageToggle(),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        bottom: false, // nav bar handles its own safe area
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Inline header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.greeting(lang, patientName),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.of(lang, 'home.subtitle'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _subtitleColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _aiReady
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEF9C3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _aiReady
                                  ? Icons.check_circle
                                  : Icons.hourglass_empty,
                              size: 14,
                              color: _aiReady
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFCA8A04),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _aiReady ? AppStrings.of(lang, 'home.ai_ready') : AppStrings.of(lang, 'home.ai_loading'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _aiReady
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFCA8A04),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // ── Card area ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // Processing overlay replaces content while AI is running
                    if (sessionState == SessionState.processing)
                      _ProcessingCard(text: AppStrings.of(lang, 'home.processing'))
                    else ...[
                      _TriageCard(
                        icon: _isRecording ? Icons.stop : Icons.mic,
                        iconBg: _isRecording ? Colors.red.shade100 : _iconCircle,
                        iconColor: _isRecording ? Colors.red : _iconColor,
                        cardColor: _isRecording ? Colors.red.shade50 : _surfaceCard,
                        title: _isRecording
                            ? AppStrings.of(lang, 'home.voice_recording')
                            : AppStrings.of(lang, 'home.voice_title'),
                        subtitle: _isRecording
                            ? AppStrings.of(lang, 'home.voice_stop')
                            : AppStrings.of(lang, 'home.voice_subtitle'),
                        onTap: _onMicTap,
                      ),
                      const SizedBox(height: 16),
                      _TriageCard(
                        icon: Icons.photo_camera,
                        title: AppStrings.of(lang, 'home.photo_title'),
                        subtitle: AppStrings.of(lang, 'home.photo_subtitle'),
                        onTap: _onCameraTap,
                      ),
                      const SizedBox(height: 16),
                      _TriageCard(
                        icon: Icons.edit_note,
                        title: AppStrings.of(lang, 'home.text_title'),
                        subtitle: AppStrings.of(lang, 'home.text_subtitle'),
                        onTap: () => _showTextDialog(lang),
                      ),
                      const SizedBox(height: 16),
                      _EmergencyCard(
                        title: AppStrings.of(lang, 'home.emergency_title'),
                        subtitle: AppStrings.of(lang, 'home.emergency_subtitle'),
                        semanticLabel: AppStrings.of(lang, 'home.emergency_label'),
                        onTap: _onEmergencyTap,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const AppBottomNavBar(),
          ],
        ),
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

class _TriageCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color cardColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TriageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBg    = _iconCircle,
    this.iconColor = _iconColor,
    this.cardColor = _surfaceCard,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                spreadRadius: -2,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: _subtitleColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String semanticLabel;
  const _EmergencyCard({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          decoration: BoxDecoration(
            color: _errorRed,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _errorRed.withValues(alpha: 0.30),
                blurRadius: 12,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  final String text;
  const _ProcessingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _iconColor),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: _titleColor),
          ),
        ],
      ),
    );
  }
}

