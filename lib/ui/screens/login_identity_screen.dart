// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/cnp_service.dart';
import '../theme/theme.dart';

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
    final valid = RegExp(r'^07\d{8}$').hasMatch(phone);
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

  void _showAjutorModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        final lang = ref.read(languageProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppStrings.of(lang, 'login.help_title'),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 16),
                Text(AppStrings.of(lang, 'login.help_desc'),
                    style: const TextStyle(fontSize: 18, color: Colors.black)),
                const SizedBox(height: 32),
                AccessibleTouchTarget(
                  semanticLabel: AppStrings.of(lang, 'login.camera_sem'),
                  onTap: () {
                    Navigator.pop(context);
                    _extractViaCamera();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BA4CF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                        const SizedBox(width: 16),
                        Text(AppStrings.of(lang, 'login.camera_btn'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AccessibleTouchTarget(
                  semanticLabel: AppStrings.of(lang, 'login.voice_sem'),
                  onTap: () {
                    Navigator.pop(context);
                    _extractViaVoice();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BA4CF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic, color: Colors.white, size: 32),
                        const SizedBox(width: 16),
                        Text(AppStrings.of(lang, 'login.voice_btn'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _extractViaCamera() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cameraService = ref.read(cameraServiceProvider);
      final hasPermission = await cameraService.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(AppStrings.of(ref.read(languageProvider), 'home.cam_no_perm'),
                style: const TextStyle(fontSize: 18)),
          ));
        }
        return;
      }

      final imagePath = await cameraService.captureImage();
      if (imagePath == null) return;

      final aiEngine = ref.read(aiEngineServiceProvider);
      final result = await aiEngine.evaluateMedia(
        File(imagePath),
        customPrompt:
            'Aceasta este o fotografie a unui act de identitate românesc (CI/BI/Pașaport). '
            'Extrage CNP-ul (numărul de 13 cifre) și numărul de telefon dacă sunt vizibile. '
            'Răspunde DOAR cu JSON: {"cnp": "...", "phone": "..."}',
      );
      cameraService.deleteTempFile(imagePath);

      if (result.containsKey('cnp')) {
        _cnpController.text = result['cnp'].toString();
      }
      if (result.containsKey('phone')) {
        _phoneController.text = result['phone'].toString();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('${AppStrings.of(ref.read(languageProvider), 'login.cam_error')} $e',
              style: const TextStyle(fontSize: 18))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _extractViaVoice() async {
    final messenger = ScaffoldMessenger.of(context);
    final audioService = ref.read(audioRecordingServiceProvider);

    final hasPermission = await audioService.requestPermission();
    if (!mounted) return;
    if (!hasPermission) {
      messenger.showSnackBar(SnackBar(
        content: Text(AppStrings.of(ref.read(languageProvider), 'home.mic_no_perm'),
            style: const TextStyle(fontSize: 18)),
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await audioService.startRecording();

      // Show countdown so the patient knows to speak now.
      messenger.showSnackBar(SnackBar(
        content: Text(AppStrings.of(ref.read(languageProvider), 'login.voice_listening'),
            style: const TextStyle(fontSize: 18)),
        duration: const Duration(seconds: 8),
      ));

      await Future.delayed(const Duration(seconds: 8));
      if (!mounted) return;

      final wavPath = await audioService.stopRecording();
      if (wavPath.isEmpty) {
        messenger.showSnackBar(SnackBar(
          content: Text(AppStrings.of(ref.read(languageProvider), 'login.voice_no_data'),
              style: const TextStyle(fontSize: 18)),
        ));
        return;
      }

      final aiEngine = ref.read(aiEngineServiceProvider);
      final result = await aiEngine.evaluateAudio(
        File(wavPath),
        customPrompt:
            'You are a medical speech-to-text assistant. The user is dictating their personal details. Extract the 13-digit CNP and/or Phone number. Output JSON strictly constrained to: {"cnp": "1234567890123", "phone": "07..."} (include fields only if detected)',
      );
      audioService.deleteWavFile(wavPath);

      final cnp   = result['cnp']   as String?;
      final phone = result['phone'] as String?;

      if ((cnp == null || cnp.isEmpty) && (phone == null || phone.isEmpty)) {
        messenger.showSnackBar(SnackBar(
          content: Text(
            AppStrings.of(ref.read(languageProvider), 'login.voice_no_data'),
            style: const TextStyle(fontSize: 18),
          ),
        ));
      } else {
        if (cnp != null && cnp.isNotEmpty) _cnpController.text = cnp;
        if (phone != null && phone.isNotEmpty) _phoneController.text = phone;
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('${AppStrings.of(ref.read(languageProvider), 'login.voice_error')} $e',
              style: const TextStyle(fontSize: 18))));
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
