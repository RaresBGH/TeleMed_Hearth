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

  @override
  void initState() {
    super.initState();
    _cnpController.addListener(_onCnpChanged);
  }

  void _onCnpChanged() {
    final valid = CnpService.isValid(_cnpController.text.trim());
    if (valid != _cnpValid) {
      setState(() => _cnpValid = valid);
    }
  }

  void _showAjutorModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ajutor Multimodal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 16),
                const Text('Alegeți metoda preferată de a completa datele:', style: TextStyle(fontSize: 18, color: Colors.black)),
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
                        Text('Cameră (Buletin)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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
                        Text('Voce', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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
        customPrompt: 'You are an offline OCR assistant. Extract the patient CNP (Cod Numeric Personal, exactly 13 digits) from the ID card image. Output JSON strictly constrained to: {"cnp": "1234567890123"}',
      );
      if (result.containsKey('cnp')) {
        _cnpController.text = result['cnp'].toString();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Eroare cameră: $e', style: const TextStyle(fontSize: 18))));
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
        customPrompt: 'You are a medical speech-to-text assistant. The user is dictating their personal details. Extract the 13-digit CNP and/or Phone number. Output JSON strictly constrained to: {"cnp": "1234567890123", "phone": "07..."} (include fields only if detected)',
      );
      if (result.containsKey('cnp')) _cnpController.text = result['cnp'].toString();
      if (result.containsKey('phone')) _phoneController.text = result['phone'].toString();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Eroare voce: $e', style: const TextStyle(fontSize: 18))));
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
    ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.loginVerification);
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
            Text('Autentificare', style: TextStyle(color: Color(0xFF5BA4CF), fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      // ── DIAGNOSTIC BODY — temporary to isolate rendering layer ────────────
      // Replace with full CNP/phone form once rendering is confirmed working.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'TEST - Dacă vedeți acest text, scroll-ul funcționează',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'CNP Test',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {},
                child: const Text('TEST BUTON', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AccessibleTouchTarget(
                semanticLabel: 'Acasă',
                onTap: () => ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.home),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home, color: Colors.black, size: 40),
                    Text('Acasă', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              ),
              AccessibleTouchTarget(
                semanticLabel: 'Ajutor',
                onTap: _showAjutorModal,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline, color: Colors.black, size: 40),
                    Text('Ajutor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              ),
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
