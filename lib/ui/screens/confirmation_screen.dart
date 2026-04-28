// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final String? aiResponse =
        ref.read(medicalSessionProvider.notifier).lastAiResponse;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.check_circle, size: 100, color: Color(0xFF5BA4CF)),
              const SizedBox(height: 32),
              Text(
                AppStrings.of(lang, 'confirm.title'),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.of(lang, 'confirm.subtitle'),
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              if (aiResponse != null && aiResponse.isNotEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECF4FD),
                    borderRadius: BorderRadius.circular(16),
                    border: const Border(
                      left: BorderSide(color: Color(0xFF5BA4CF), width: 6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.smart_toy_outlined,
                              color: Color(0xFF5BA4CF), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.of(lang, 'confirm.ai_label'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5BA4CF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        aiResponse,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
