// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/ai_engine_service.dart';
import '../theme/theme.dart';
import '../widgets/language_toggle.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.addListener(() => setState(() {}));
    _lastNameCtrl.addListener(() => setState(() {}));
    _phoneCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      RegExp(r'^07\d{8}$').hasMatch(_phoneCtrl.text.trim());

  Future<void> _onSave() async {
    if (!_canSave || _isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final cnp = ref.read(loginCnpProvider);
      await ref.read(patientAuthProvider.notifier).registerNewPatient(
            cnp: cnp,
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
          );
      if (!mounted) return;
      ref.read(appNavigationProvider.notifier).navigateTo(
          await AiEngineService.isModelOnDisk() ? AppRoute.dashboard : AppRoute.modelDownload);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = AppStrings.of(ref.read(languageProvider), 'profile.save_error');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F3F3),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        actions: const [
          LanguageToggle(),
          SizedBox(width: 16),
        ],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add, color: Color(0xFF5BA4CF), size: 32),
            const SizedBox(width: 8),
            Text(
              AppStrings.of(lang, 'profile.appbar_title'),
              style: TextStyle(
                color: Color(0xFF5BA4CF),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isSaving
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF5BA4CF)))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.of(lang, 'profile.heading'),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.of(lang, 'profile.desc'),
                      style: TextStyle(
                          fontSize: 18, color: Colors.black54, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    _buildField(
                      label: AppStrings.of(lang, 'profile.first_name'),
                      controller: _firstNameCtrl,
                      hint: AppStrings.of(lang, 'profile.first_hint'),
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 24),

                    _buildField(
                      label: AppStrings.of(lang, 'profile.last_name'),
                      controller: _lastNameCtrl,
                      hint: AppStrings.of(lang, 'profile.last_hint'),
                      icon: Icons.badge,
                    ),
                    const SizedBox(height: 24),

                    _buildField(
                      label: AppStrings.of(lang, 'profile.phone'),
                      controller: _phoneCtrl,
                      hint: AppStrings.of(lang, 'profile.phone_hint'),
                      icon: Icons.call,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 16, color: Colors.red),
                        ),
                      ),
                    ],

                    const SizedBox(height: 48),

                    AccessibleTouchTarget(
                      semanticLabel: AppStrings.of(lang, 'profile.continue_sem'),
                      onTap: _onSave,
                      child: Container(
                        height: 96,
                        decoration: BoxDecoration(
                          color: _canSave
                              ? const Color(0xFF5BA4CF)
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: _canSave
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
                            Text(
                              AppStrings.of(lang, 'profile.continue_btn'),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                            SizedBox(width: 16),
                            Icon(Icons.arrow_forward,
                                color: Colors.white, size: 40),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    hintText: hint,
                    hintStyle:
                        const TextStyle(fontSize: 22, color: Colors.black54),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 24.0),
                child: Icon(icon, size: 36, color: Colors.black26),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
