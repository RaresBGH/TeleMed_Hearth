// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_auth/smart_auth.dart';
import '../widgets/legal_document_modal.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/ai_engine_service.dart';
import '../../core/services/cnp_service.dart';

class LoginVerificationScreen extends ConsumerStatefulWidget {
  const LoginVerificationScreen({super.key});

  @override
  ConsumerState<LoginVerificationScreen> createState() => _LoginVerificationScreenState();
}

class _LoginVerificationScreenState extends ConsumerState<LoginVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isAuthenticating = false;
  int _attempts = 0;
  bool _isLocked = false;

  static const _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    _startSmsListener();
  }

  void _startSmsListener() async {
    final smartAuth = SmartAuth.instance;
    final res = await smartAuth.getSmsWithUserConsentApi();
    if (res.hasData && res.data?.code != null) {
      final code = res.data!.code!;
      if (code.length >= 6) {
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = code[i];
        }
        // Rebuild so the button enables after SMS autofill.
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    SmartAuth.instance.removeUserConsentApiListener();
    for (final c in _controllers) { c.dispose(); }
    for (final n in _focusNodes) { n.dispose(); }
    super.dispose();
  }

  void _onDigitChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
    if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
    // Rebuild so the button enabled condition re-evaluates on every keystroke.
    setState(() {});
  }

  void _openLegalModal(BuildContext context, String title, String content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentModal(title: title, content: content),
        fullscreenDialog: true,
      ),
    );
  }

  void _onConfirmAndCreateAccount() {
    if (_isLocked || _isAuthenticating) return;

    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) return;

    final cnp = ref.read(loginCnpProvider);
    final expectedOtp = CnpService.extractDemoOtp(cnp);

    setState(() => _isAuthenticating = true);

    // Small artificial delay so the spinner is visible — mimics network call
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);

      if (otp == expectedOtp) {
        // Determine whether this CNP belongs to an existing registered patient.
        final isReturning =
            await ref.read(patientAuthProvider.notifier).loadPatient(cnp);
        if (!mounted) return;
        if (isReturning) {
          final modelOnDisk = await AiEngineService.isModelOnDisk();
          if (!mounted) return;
          ref.read(appNavigationProvider.notifier).navigateTo(
            modelOnDisk ? AppRoute.dashboard : AppRoute.modelDownload,
          );
        } else {
          // New user — collect profile details before proceeding.
          ref
              .read(appNavigationProvider.notifier)
              .navigateTo(AppRoute.profileCompletion);
        }
      } else {
        final newAttempts = _attempts + 1;
        if (newAttempts >= _maxAttempts) {
          setState(() {
            _attempts = newAttempts;
            _isLocked = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.of(ref.read(languageProvider), 'otp.locked_msg'),
                style: const TextStyle(fontSize: 18),
              ),
              duration: const Duration(seconds: 6),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          setState(() => _attempts = newAttempts);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.otpWrongCode(ref.read(languageProvider), _maxAttempts - newAttempts),
                style: const TextStyle(fontSize: 18),
              ),
              backgroundColor: Colors.orange.shade800,
            ),
          );
          // Clear fields for retry
          for (final c in _controllers) { c.clear(); }
          _focusNodes[0].requestFocus();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        title: Text(
          AppStrings.of(lang, 'otp.title'),
          style: TextStyle(color: Color(0xFF000000), fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.of(lang, 'otp.subtitle'),
                style: TextStyle(color: Color(0xFF000000), fontSize: 24, fontWeight: FontWeight.bold, height: 1.2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 6-digit OTP fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    height: 70,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      enabled: !_isLocked,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                      onChanged: (value) => _onDigitChanged(value, index),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: _isLocked ? Colors.grey.shade200 : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF000000), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4A93BE), width: 4),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF000000), width: 2),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 64),

              // Visual context card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: Color(0xFF5BA4CF), width: 8)),
                ),
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.security, color: Color(0xFF5BA4CF), size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        AppStrings.of(lang, 'otp.security_text'),
                        style: const TextStyle(color: Color(0xFF000000), fontSize: 18, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 64),

              // CTA or lockout message
              if (_isLocked)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Text(
                    AppStrings.of(lang, 'otp.locked_msg'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: (_isAuthenticating ||
                          _isLocked ||
                          _controllers.map((c) => c.text).join().length < 6)
                      ? null
                      : _onConfirmAndCreateAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5BA4CF),
                    disabledBackgroundColor: Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    elevation: 0,
                  ),
                  child: _isAuthenticating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          AppStrings.of(lang, 'otp.confirm_btn'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                ),

              const SizedBox(height: 32),

              if (!_isLocked)
                GestureDetector(
                  onTap: _startSmsListener,
                  child: Text(
                    AppStrings.of(lang, 'otp.resend'),
                    style: TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 48),

              // Legal documents
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _openLegalModal(
                      context,
                      AppStrings.of(lang, 'otp.terms_title'),
                      'Placeholder pentru Termeni de Utilizare.\n\n1. Acceptarea Termenilor\nPrin accesarea și utilizarea acestei aplicații, confirmați că ați citit, înțeles și sunteți de acord cu acești termeni. Serviciul nostru este dedicat exclusiv utilizării personale, oferind suport pentru sănătate și monitorizare zilnică, respectând cele mai înalte standarde de etică digitală.\n\n2. Confidențialitatea Datelor\nProtecția informațiilor dumneavoastră este prioritatea noastră absolută.',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: const Color(0xFF000000),
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                    child: Text(AppStrings.of(lang, 'otp.terms_btn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _openLegalModal(
                      context,
                      AppStrings.of(lang, 'otp.privacy_title'),
                      'Placeholder pentru Politica de Confidențialitate.\n\nModul de stocare al datelor:\nToate datele medicale sunt stocate local pe dispozitiv via Google Android FHIR SDK SQLCipher.\n\nFără Telemetrie Ascunsă:\nInference-ul se realizează exclusiv On-Device utilizând LiteRT-LM (Gemma 4 E2B). Nu vor exista apeluri către servere cloud pentru procesarea RAG.\n',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: const Color(0xFF000000),
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                    child: Text(AppStrings.of(lang, 'otp.privacy_btn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Demo hint — visible to competition judges
              Text(
                AppStrings.of(lang, 'otp.demo_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black38),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

}
