// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF000000);

  static const Color backgroundDark = Color(0xFF1A1C1E);
  static const Color surfaceDark = Color(0xFF2C2F33);
  static const Color onSurfaceDark = Color(0xFFF5F7FA);
  static const Color primaryBlue = Color(0xFF5BA4CF);
  static const Color errorRed = Color(0xFFAB1118);

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: textPrimary,
        surface: backgroundLight,
        onSurface: textPrimary,
      ),
      // Apply Lexend to every text style in the app, then enforce minimum
      // sizes required for elderly-patient accessibility.
      textTheme: GoogleFonts.lexendTextTheme().copyWith(
        bodyMedium: GoogleFonts.lexend(fontSize: 18.0, color: textPrimary),
        bodyLarge: GoogleFonts.lexend(fontSize: 20.0, color: textPrimary),
        labelLarge: GoogleFonts.lexend(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displaySmall: GoogleFonts.lexend(
          fontSize: 28.0,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundLight,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        surface: surfaceDark,
        onSurface: onSurfaceDark,
        error: errorRed,
      ),
      textTheme: GoogleFonts.lexendTextTheme().copyWith(
        bodyMedium: GoogleFonts.lexend(fontSize: 18.0, color: onSurfaceDark),
        bodyLarge: GoogleFonts.lexend(fontSize: 20.0, color: onSurfaceDark),
        labelLarge: GoogleFonts.lexend(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: onSurfaceDark,
        ),
        displaySmall: GoogleFonts.lexend(
          fontSize: 28.0,
          fontWeight: FontWeight.bold,
          color: onSurfaceDark,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: onSurfaceDark,
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
