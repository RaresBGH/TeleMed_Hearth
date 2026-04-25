// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/providers/auth_provider.dart';
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
  bool _isLoading = false;
  bool _cnpValid = false;
  String? _ageError;

  @override
  void initState() {
    super.initState();
    _cnpController.addListener(_onCnpChanged);
  }

  void _onCnpChanged() {
    final cnp = _cnpController.text.trim();
    final checksumOk = CnpService.isValid(cnp);

    bool newValid = checksumOk;
    String? newAgeError;

    if (checksumOk && !CnpService.isAdult(cnp)) {
      newAgeError = 'Vârsta minimă este 18 ani.';
      newValid = false;
    }

    if (newValid != _cnpValid || newAgeError != _ageError) {
      setState(() {
        _cnpValid = newValid;
        _ageError = newAgeError;
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ajutor Multimodal',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 16),
                const Text('Alegeți metoda preferată de a completa datele:',
                    style: TextStyle(fontSize: 18, color: Colors.black)),
                const SizedBox(height: 32),
                AccessibleTouchTarget(
                  semanticLabel: 'Folosește Camera pentru Buletin',
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 32),
                        SizedBox(width: 16),
                        Text('Cameră (Buletin)',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AccessibleTouchTarget(
                  semanticLabel: 'Folosește Vocea',
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic, color: Colors.white, size: 32),
                        SizedBox(width: 16),
                        Text('Voce',
                            style: TextStyle(
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
      final aiEngine = ref.read(aiEngineServiceProvider);
      final dummyFile = File('dummy_id.jpg');
      final result = await aiEngine.evaluateMedia(
        dummyFile,
        customPrompt:
            'You are an offline OCR assistant. Extract the patient CNP (Cod Numeric Personal, exactly 13 digits) from the ID card image. Output JSON strictly constrained to: {"cnp": "1234567890123"}',
      );
      if (result.containsKey('cnp')) {
        _cnpController.text = result['cnp'].toString();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content:
              Text('Eroare cameră: $e', style: const TextStyle(fontSize: 18))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _extractViaVoice() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final aiEngine = ref.read(aiEngineServiceProvider);
      final dummyAudio = File('dummy_voice.wav');
      final result = await aiEngine.evaluateAudio(
        dummyAudio,
        customPrompt:
            'You are a medical speech-to-text assistant. The user is dictating their personal details. Extract the 13-digit CNP and/or Phone number. Output JSON strictly constrained to: {"cnp": "1234567890123", "phone": "07..."} (include fields only if detected)',
      );
      if (result.containsKey('cnp')) {
        _cnpController.text = result['cnp'].toString();
      }
      if (result.containsKey('phone')) {
        _phoneController.text = result['phone'].toString();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content:
              Text('Eroare voce: $e', style: const TextStyle(fontSize: 18))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onContinuaTap() {
    if (!_cnpValid) return;
    final cnp = _cnpController.text.trim();
    ref.read(loginCnpProvider.notifier).setCnp(cnp);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Codul de verificare a fost trimis la numărul asociat CNP-ului dumneavoastră. Introduceți codul primit.',
          style: TextStyle(fontSize: 16),
        ),
        duration: Duration(seconds: 4),
      ),
    );
    ref
        .read(appNavigationProvider.notifier)
        .navigateTo(AppRoute.loginVerification);
  }

  @override
  Widget build(BuildContext context) {
    final cnpText = _cnpController.text;
    final showIndicator = cnpText.length == 13;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F3F3),
        elevation: 0,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield, color: Color(0xFF5BA4CF), size: 32),
            SizedBox(width: 8),
            Text('Autentificare',
                style: TextStyle(
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
                    const Text(
                      'Sănătatea ta,\nla un click distanță',
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
                    const Text('CNP (Cod Numeric Personal)',
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
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 24),
                                hintText: 'Introduceți cele 13 cifre',
                                hintStyle: TextStyle(
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
                    const Text('Număr de Telefon',
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
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 24),
                                hintText: 'Ex: 0722 000 000',
                                hintStyle: TextStyle(
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
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info,
                              color: Color(0xFF5BA4CF), size: 36),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Dacă aveți nevoie de ajutor, apăsați butonul de Ajutor de mai jos. Câmpurile pot fi completate audio sau prin fotografierea actului de identitate.',
                              style: TextStyle(
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
                      semanticLabel: 'Continuă autentificarea',
                      onTap: _onContinuaTap,
                      child: Container(
                        height: 96,
                        decoration: BoxDecoration(
                          color: _cnpValid
                              ? const Color(0xFF5BA4CF)
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.black, width: 2),
                          boxShadow: _cnpValid
                              ? const [
                                  BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(0, 8))
                                ]
                              : null,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('CONTINUĂ',
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2.0)),
                            SizedBox(width: 16),
                            Icon(Icons.arrow_forward,
                                color: Colors.white, size: 40),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Ajutor link (moved from bottom nav) ────────────────
                    AccessibleTouchTarget(
                      semanticLabel: 'Deschide meniu ajutor',
                      onTap: _showAjutorModal,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.help_outline,
                              color: Color(0xFF5BA4CF), size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Ajutor',
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
    _cnpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
