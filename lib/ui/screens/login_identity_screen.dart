// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/ai_engine_service.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/cnp_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/utils/validators.dart';
import '../theme/theme.dart';
import '../widgets/language_toggle.dart';

class LoginIdentityScreen extends ConsumerStatefulWidget {
  const LoginIdentityScreen({super.key});

  @override
  ConsumerState<LoginIdentityScreen> createState() => _LoginIdentityScreenState();
}

class _LoginIdentityScreenState extends ConsumerState<LoginIdentityScreen> {
  final TextEditingController _cnpController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading  = false;
  bool _cnpValid   = false;
  bool _phoneValid = false;
  String? _ageError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _cnpController.addListener(_onCnpChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onCnpChanged() {
    final cnp = _cnpController.text.trim();
    final checksumOk = CnpService.isValid(cnp);

    bool newValid = checksumOk;
    String? newAgeError;

    if (checksumOk && !CnpService.isAdult(cnp)) {
      newAgeError = AppStrings.of(ref.read(languageProvider), 'login.age_error');
      newValid = false;
    }

    if (newValid != _cnpValid || newAgeError != _ageError) {
      setState(() {
        _cnpValid = newValid;
        _ageError = newAgeError;
      });
    }
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    final valid = Validators.isValidRomanianPhone(phone);
    final String? err = (phone.isNotEmpty && !valid)
        ? AppStrings.of(ref.read(languageProvider), 'login.phone_error')
        : null;
    if (valid != _phoneValid || err != _phoneError) {
      setState(() {
        _phoneValid = valid;
        _phoneError = err;
      });
    }
  }

  Future<void> _showAjutorModal() async {
    final lang = ref.read(languageProvider);

    // Guard: show info dialog when AI model is not on disk.
    if (!await AiEngineService.isModelOnDisk()) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.of(lang, 'ajutor.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: Text(AppStrings.of(lang, 'ajutor.model_not_ready'),
              style: const TextStyle(fontSize: 16)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5BA4CF)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppStrings.of(lang, 'action.ok'), style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppStrings.of(lang, 'ajutor.title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 24),
                AccessibleTouchTarget(
                  semanticLabel: AppStrings.of(lang, 'ajutor.photo_option'),
                  onTap: () { Navigator.pop(ctx); _extractViaCamera(); },
                  child: _ajutorOption(Icons.camera_alt, AppStrings.of(lang, 'ajutor.photo_option')),
                ),
                const SizedBox(height: 16),
                AccessibleTouchTarget(
                  semanticLabel: AppStrings.of(lang, 'ajutor.voice_option'),
                  onTap: () { Navigator.pop(ctx); _extractViaVoice(); },
                  child: _ajutorOption(Icons.mic, AppStrings.of(lang, 'ajutor.voice_option')),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _ajutorOption(IconData icon, String label) => Container(
    width: double.infinity,
    height: 80,
    decoration: BoxDecoration(
      color: const Color(0xFF5BA4CF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    ),
  );

  Future<void> _extractViaCamera() async {
    final lang = ref.read(languageProvider);
    final messenger = ScaffoldMessenger.of(context);
    final cameraService = ref.read(cameraServiceProvider);

    final hasPermission = await cameraService.requestPermission();
    if (!mounted) return;
    if (!hasPermission) {
      messenger.showSnackBar(SnackBar(
        content: Text(AppStrings.of(lang, 'home.cam_no_perm'),
            style: const TextStyle(fontSize: 18)),
      ));
      return;
    }

    final imagePath = await cameraService.captureImage();
    if (imagePath == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      // Use ML Kit OCR — no AI model required.
      final text = await OcrService.extractText(imagePath);
      cameraService.deleteTempFile(imagePath);

      if (text.isEmpty) {
        // Empty = timeout (15s) or no text detected — show specific error.
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text(AppStrings.of(lang, 'ocr.timeout_error'),
              style: const TextStyle(fontSize: 18)),
        ));
        return;
      }

      final cnp   = OcrService.parseCnp(text);
      final phone = OcrService.parsePhone(text);

      if (cnp   != null) _cnpController.text   = cnp;
      if (phone != null) _phoneController.text = phone;

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
          cnp != null
              ? AppStrings.of(lang, 'ajutor.cnp_detected')
              : AppStrings.of(lang, 'ajutor.cnp_not_found'),
          style: const TextStyle(fontSize: 18),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('${AppStrings.of(lang, 'login.cam_error')} $e',
            style: const TextStyle(fontSize: 18)),
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _extractViaVoice() async {
    final lang = ref.read(languageProvider);
    final messenger = ScaffoldMessenger.of(context);
    final audioService = ref.read(audioRecordingServiceProvider);

    final hasPermission = await audioService.requestPermission();
    if (!mounted) return;
    if (!hasPermission) {
      messenger.showSnackBar(SnackBar(
        content: Text(AppStrings.of(lang, 'home.mic_no_perm'),
            style: const TextStyle(fontSize: 18)),
      ));
      return;
    }

    try {
      await audioService.startRecording();
    } catch (e) {
      debugPrint('Voice recording error: $e');
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!mounted) return;

    // Show 15-second countdown dialog with animated progress bar.
    int secondsLeft = 15;
    Timer? countdownTimer;
    bool manualStop = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (secondsLeft <= 1) {
              countdownTimer?.cancel();
              if (!manualStop && ctx.mounted) Navigator.of(ctx).pop();
            } else {
              setDialogState(() => secondsLeft--);
            }
          });
          return AlertDialog(
            title: Text(AppStrings.of(lang, 'ajutor.voice_recording'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic, size: 56, color: Color(0xFF5BA4CF)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: secondsLeft / 15.0,
                    minHeight: 10,
                    color: const Color(0xFF5BA4CF),
                    backgroundColor: const Color(0xFFE0E0E0),
                  ),
                ),
                const SizedBox(height: 8),
                Text(AppStrings.of(lang, 'action.seconds_left').replaceAll('{n}', secondsLeft.toString()),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5BA4CF)),
                onPressed: () {
                  manualStop = true;
                  countdownTimer?.cancel();
                  Navigator.of(ctx).pop();
                },
                child: Text(AppStrings.of(lang, 'ajutor.voice_gata'),
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          );
        },
      ),
    );

    countdownTimer?.cancel();
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final wavPath = await audioService.stopRecording();
      if (wavPath.isEmpty) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(AppStrings.of(lang, 'ajutor.voice_failed'),
                style: const TextStyle(fontSize: 18)),
          ));
        }
        return;
      }

      final aiEngine = ref.read(aiEngineServiceProvider);
      final result   = await aiEngine.evaluateAudio(
        File(wavPath),
        customPrompt:
            'Extrage din textul următor un CNP (13 cifre) și un număr de telefon '
            '(format 07XXXXXXXX). Răspunde DOAR cu JSON: '
            '{"cnp":"...","phone":"..."} sau null dacă nu găsești.',
      );
      audioService.deleteWavFile(wavPath);

      final cnpRaw   = result['cnp']   as String?;
      final phoneRaw = result['phone'] as String?;

      // Validate before filling — AI sometimes returns extra digits or
      // puts phone in the CNP field. Enforce exact formats.
      final validCnp = (cnpRaw != null &&
              RegExp(r'^\d{13}$').hasMatch(cnpRaw.trim()))
          ? cnpRaw.trim()
          : null;
      final validPhone = (phoneRaw != null &&
              Validators.isValidRomanianPhone(phoneRaw.trim()))
          ? phoneRaw.trim()
          : null;

      if (validCnp   != null) _cnpController.text   = validCnp;
      if (validPhone != null) _phoneController.text = validPhone;

      if (!mounted) return;
      if (validCnp == null && validPhone == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(AppStrings.of(lang, 'ocr.voice_parse_error'),
              style: const TextStyle(fontSize: 18)),
        ));
      } else if (validCnp == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(AppStrings.of(lang, 'ajutor.voice_failed'),
              style: const TextStyle(fontSize: 18)),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(AppStrings.of(lang, 'ajutor.voice_failed'),
            style: const TextStyle(fontSize: 18)),
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onContinuaTap() {
    if (!_cnpValid || !_phoneValid) return;
    final cnp = _cnpController.text.trim();
    ref.read(loginCnpProvider.notifier).setCnp(cnp);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.of(ref.read(languageProvider), 'login.otp_sent'),
          style: const TextStyle(fontSize: 16),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
    ref
        .read(appNavigationProvider.notifier)
        .navigateTo(AppRoute.loginVerification);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final cnpText = _cnpController.text;
    final showIndicator = cnpText.length == 13;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F3F3),
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, color: Color(0xFF5BA4CF), size: 32),
            const SizedBox(width: 8),
            Text(AppStrings.of(lang, 'login.appbar'),
                style: const TextStyle(
                    color: Color(0xFF5BA4CF),
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: const [
          LanguageToggle(),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF5BA4CF)))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Title ──────────────────────────────────────────────
                    Text(
                      AppStrings.of(lang, 'login.title'),
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          height: 1.2),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        height: 6,
                        width: 96,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5BA4CF),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── CNP Field ──────────────────────────────────────────
                    Text(AppStrings.of(lang, 'login.cnp_label'),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    const SizedBox(height: 12),
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: showIndicator
                              ? (_cnpValid ? Colors.green : Colors.red)
                              : Colors.black,
                          width: showIndicator ? 2.5 : 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cnpController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(13),
                              ],
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                hintText: AppStrings.of(lang, 'login.cnp_hint'),
                                hintStyle: const TextStyle(
                                    fontSize: 24, color: Colors.black54),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 24.0),
                            child: showIndicator
                                ? Icon(
                                    _cnpValid
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 40,
                                    color: _cnpValid
                                        ? Colors.green
                                        : Colors.red,
                                  )
                                : const Icon(Icons.fingerprint,
                                    size: 40, color: Colors.black26),
                          ),
                        ],
                      ),
                    ),
                    if (_ageError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          _ageError!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // ── Phone Field ────────────────────────────────────────
                    Text(AppStrings.of(lang, 'login.phone_label'),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    const SizedBox(height: 12),
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.black, width: 2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                hintText: AppStrings.of(lang, 'login.phone_hint'),
                                hintStyle: const TextStyle(
                                    fontSize: 24, color: Colors.black54),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(right: 24.0),
                            child: Icon(Icons.call,
                                size: 40, color: Colors.black26),
                          ),
                        ],
                      ),
                    ),
                    if (_phoneError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          _phoneError!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 48),

                    // ── Info prompt ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(16),
                        border: const Border(
                            left: BorderSide(
                                color: Color(0xFF5BA4CF), width: 8)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info,
                              color: Color(0xFF5BA4CF), size: 36),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              AppStrings.of(lang, 'login.info_text'),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ── CONTINUĂ ───────────────────────────────────────────
                    AccessibleTouchTarget(
                      semanticLabel: AppStrings.of(lang, 'login.continue_sem'),
                      onTap: _onContinuaTap,
                      child: Container(
                        height: 96,
                        decoration: BoxDecoration(
                          color: (_cnpValid && _phoneValid)
                              ? const Color(0xFF5BA4CF)
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.black, width: 2),
                          boxShadow: (_cnpValid && _phoneValid)
                              ? const [
                                  BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(0, 8))
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(AppStrings.of(lang, 'login.continue_btn'),
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2.0)),
                            const SizedBox(width: 16),
                            const Icon(Icons.arrow_forward,
                                color: Colors.white, size: 40),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Ajutor link (moved from bottom nav) ────────────────
                    AccessibleTouchTarget(
                      semanticLabel: AppStrings.of(lang, 'login.help_sem'),
                      onTap: _showAjutorModal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.help_outline,
                              color: Color(0xFF5BA4CF), size: 28),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.of(lang, 'login.help_btn'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5BA4CF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _cnpController.removeListener(_onCnpChanged);
    _phoneController.removeListener(_onPhoneChanged);
    _cnpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
