// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';

const Color _brand = Color(0xFF5BA4CF);

/// Two-button RO/EN pill toggle for tab-screen AppBar actions.
/// Width: 88dp  Height: 36dp  Border-radius: 6dp  Border: 1dp #5BA4CF.
/// Active side: #5BA4CF fill, white Lexend Bold 16sp.
/// Inactive side: transparent, #5BA4CF text Lexend Regular 16sp.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);

    return SizedBox(
      width: 88,
      height: 36,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _brand),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            _LangButton(
              label: 'RO',
              active: lang == 'ro',
              onTap: () {
                ref.read(languageProvider.notifier).setLanguage('ro');
                ref.read(aiEngineServiceProvider).setLanguage('ro');
              },
            ),
            _LangButton(
              label: 'EN',
              active: lang == 'en',
              onTap: () {
                ref.read(languageProvider.notifier).setLanguage('en');
                ref.read(aiEngineServiceProvider).setLanguage('en');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LangButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: active ? _brand : Colors.transparent,
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? Colors.white : _brand,
            ),
          ),
        ),
      ),
    );
  }
}
