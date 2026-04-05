// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroundLight = Color(0xFFF5F5F5); // Deep off-white
  static const Color textPrimary = Color(0xFF000000);     // Pure black text

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: textPrimary,
        surface: backgroundLight,
        onSurface: textPrimary,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 22.0, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 18.0, color: textPrimary),
        labelLarge: TextStyle(fontSize: 18.0, color: textPrimary, fontWeight: FontWeight.bold),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundLight,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}

/// Reusable wrapper ensuring any mapped interactive widget strictly maintains 
/// a minimum of 64x64 dp touch target for extreme accessibility constraints.
class AccessibleTouchTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  const AccessibleTouchTarget({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 64.0,
              minHeight: 64.0,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
