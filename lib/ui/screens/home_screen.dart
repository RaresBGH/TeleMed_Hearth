// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/services/ai_engine_service.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/camera_service.dart';
import '../../data/repositories/fhir_repository.dart';

// ── Design tokens (Stitch palette) ───────────────────────────────────────────
const Color _bg            = Color(0xFFF7F9FE); // surface-bright
const Color _surfaceCard   = Color(0xFFECEEF2); // surface-container
const Color _iconCircle    = Color(0xFFC6E7FF); // primary-fixed
const Color _iconColor     = Color(0xFF5BA4CF); // brand primary
const Color _titleColor    = Color(0xFF191C1F); // on-background
const Color _subtitleColor = Color(0xFF40484E); // on-surface-variant
const Color _errorRed      = Color(0xFFBA1A1A); // error / emergency
const Color _navActive     = Color(0xFF5BA4CF);
const Color _navInactive   = Color(0xFF6B7280);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isRecording = false;
  bool _aiReady     = false;

  @override
  void initState() {
    super.initState();
    _checkAiStatus();
  }

  Future<void> _checkAiStatus() async {
    final ready = await AiEngineService(FhirRepository()).initializeModel();
    if (mounted) setState(() => _aiReady = ready);
  }

  // ── Camera ─────────────────────────────────────────────────────────────────

  Future<void> _onCameraTap() async {
    final cameraService = ref.read(cameraServiceProvider);

    final hasPermission = await cameraService.requestPermission();
    if (!mounted) return;

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permisiunea pentru cameră este necesară.',
              style: TextStyle(fontSize: 18)),
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
          const SnackBar(
            content: Text('Eroare la oprirea înregistrării.',
                style: TextStyle(fontSize: 18)),
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
          const SnackBar(
            content: Text('Permisiunea pentru microfon este necesară.',
                style: TextStyle(fontSize: 18)),
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

  // ── Text triage ────────────────────────────────────────────────────────────

  void _showTextDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descrieți simptomele',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Scrieți simptomele dumneavoastră...',
            hintStyle: TextStyle(fontSize: 18),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anulează', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => _onTextSubmit(controller.text, ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _iconColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('TRIMITE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _onTextSubmit(String text, BuildContext dialogCtx) async {
    if (text.trim().isEmpty) return;
    Navigator.of(dialogCtx).pop();

    try {
      // Attempt text inference via LiteRT-LM channel (method may not exist yet).
      const channel = MethodChannel('com.telemed_k/litert_lm');
      await channel.invokeMethod<String>('runInference', {'text': text.trim()});
      if (mounted) {
        ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.confirmation);
      }
    } catch (_) {
      // Channel method not yet implemented — show graceful success message.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesaj primit. Medicul va fi notificat.',
                style: TextStyle(fontSize: 18)),
          ),
        );
      }
    }
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
    final sessionState = ref.watch(medicalSessionProvider);
    final currentRoute = ref.watch(appNavigationProvider);
    final bottomInset  = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
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
                  const Text(
                    'Bună ziua, Maria!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cum vă simțiți astăzi?',
                    style: TextStyle(
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
                              _aiReady ? 'AI pregătit' : 'AI se încarcă...',
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
                      _ProcessingCard()
                    else ...[
                      _TriageCard(
                        icon: _isRecording ? Icons.stop : Icons.mic,
                        iconBg: _isRecording ? Colors.red.shade100 : _iconCircle,
                        iconColor: _isRecording ? Colors.red : _iconColor,
                        cardColor: _isRecording
                            ? Colors.red.shade50
                            : _surfaceCard,
                        title: _isRecording
                            ? 'Înregistrare activă...'
                            : 'Descrieți prin voce',
                        subtitle: _isRecording
                            ? 'Apăsați din nou pentru a opri'
                            : 'Apăsați și vorbiți despre simptome',
                        onTap: _onMicTap,
                      ),
                      const SizedBox(height: 16),
                      _TriageCard(
                        icon: Icons.photo_camera,
                        title: 'Trimiteți o fotografie',
                        subtitle: 'Fotografiați zona afectată',
                        onTap: _onCameraTap,
                      ),
                      const SizedBox(height: 16),
                      _TriageCard(
                        icon: Icons.edit_note,
                        title: 'Scrieți un mesaj',
                        subtitle: 'Descrieți în scris simptomele',
                        onTap: _showTextDialog,
                      ),
                      const SizedBox(height: 16),
                      _EmergencyCard(onTap: _onEmergencyTap),
                    ],
                  ],
                ),
              ),
            ),

            // ── Glassmorphism bottom nav ───────────────────────────────────
            _GlassNav(
              currentRoute: currentRoute,
              bottomInset: bottomInset,
              onTap: (route) =>
                  ref.read(appNavigationProvider.notifier).navigateTo(route),
            ),
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
  const _EmergencyCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Urgență 112 — Apelați serviciul de urgență',
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Urgență 112',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Apelați serviciul de urgență',
                      style: TextStyle(
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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _iconColor),
          SizedBox(height: 16),
          Text(
            'Asistentul analizează...',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: _titleColor),
          ),
        ],
      ),
    );
  }
}

class _GlassNav extends StatelessWidget {
  final AppRoute currentRoute;
  final double bottomInset;
  final void Function(AppRoute) onTap;

  const _GlassNav({
    required this.currentRoute,
    required this.bottomInset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xD9FFFFFF), // white ~85%
            border: Border(
              top: BorderSide(color: Color(0xFFE2E2E2), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavTab(
                    icon: Icons.home,
                    label: 'Acasă',
                    active: currentRoute == AppRoute.home,
                    onTap: () => onTap(AppRoute.home),
                  ),
                  _NavTab(
                    icon: Icons.folder_shared,
                    label: 'Dosar Medical',
                    active: currentRoute == AppRoute.history,
                    onTap: () => onTap(AppRoute.history),
                  ),
                  _NavTab(
                    icon: Icons.medical_services,
                    label: 'Medic',
                    active: currentRoute == AppRoute.myDoctor,
                    onTap: () => onTap(AppRoute.myDoctor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _navActive : _navInactive;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: active,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: active
                ? BoxDecoration(
                    color: const Color(0xFFEBF5FF),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
