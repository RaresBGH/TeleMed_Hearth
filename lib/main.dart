// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_navigation_provider.dart';
import 'core/services/ai_engine_service.dart';
import 'data/repositories/fhir_repository.dart';
import 'ui/theme/theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/confirmation_screen.dart';
import 'ui/screens/emergency_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/model_download_screen.dart';
import 'ui/screens/my_doctor_screen.dart';
import 'ui/screens/waiting_room_screen.dart';
import 'ui/screens/video_consultation_screen.dart';
import 'ui/screens/login_identity_screen.dart';
import 'ui/screens/login_verification_screen.dart';
import 'ui/screens/medical_response_screen.dart';
import 'ui/screens/profile_completion_screen.dart';
import 'core/providers/medical_session_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the local FHIR engine (encrypted SQLite) and seed mock data
  // before the widget tree renders. Must run after ensureInitialized() because
  // it uses a MethodChannel to talk to the native Android FHIR SDK.
  try {
    await FhirRepository().initialize();
  } catch (_) {
    // Non-fatal during development when running on host without the native
    // Android FHIR SDK (e.g. flutter test on desktop).
  }

  // If model is already on disk, start loading it in background while the
  // user completes login. Navigation to the download screen now happens
  // after successful OTP verification, not here.
  final bool modelOnDisk = await _isModelFileOnDisk();
  if (modelOnDisk) {
    unawaited(AiEngineService(FhirRepository()).initializeModel());
  }

  runApp(
    const ProviderScope(
      child: TeleMedApp(),
    ),
  );
}

/// Calls getModelPath on the LiteRT-LM channel and checks whether the file
/// exists on disk. Fast (local IO only) — safe to await before runApp.
Future<bool> _isModelFileOnDisk() async {
  try {
    const channel = MethodChannel('com.telemed_k/litert_lm');
    final String? path = await channel.invokeMethod<String>('getModelPath');
    if (path == null) return false;
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

class TeleMedApp extends ConsumerWidget {
  const TeleMedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = ref.watch(appNavigationProvider);

    Widget screen;
    switch (currentRoute) {
      case AppRoute.modelDownload:
        screen = const ModelDownloadScreen();
        break;
      case AppRoute.emergency:
        screen = const EmergencyScreen();
        break;
      case AppRoute.confirmation:
        screen = const ConfirmationScreen();
        break;
      case AppRoute.medicalResponse:
        final notifier = ref.read(medicalSessionProvider.notifier);
        screen = MedicalResponseScreen(
          initialResponse:
              notifier.lastAiResponse ?? 'Simptomele au fost înregistrate.',
          isEmergency: notifier.lastIsEmergency,
          initialMessages: notifier.lastResumeMessages,
        );
        break;
      case AppRoute.home:
        screen = const HomeScreen();
        break;
      case AppRoute.history:
        screen = const HistoryScreen();
        break;
      case AppRoute.myDoctor:
        screen = const MyDoctorScreen();
        break;
      case AppRoute.waitingRoom:
        screen = const WaitingRoomScreen();
        break;
      case AppRoute.videoConsultation:
        screen = const VideoConsultationScreen();
        break;
      case AppRoute.loginIdentity:
        screen = const LoginIdentityScreen();
        break;
      case AppRoute.loginVerification:
        screen = const LoginVerificationScreen();
        break;
      case AppRoute.profileCompletion:
        screen = const ProfileCompletionScreen();
        break;
    }

    return MaterialApp(
      title: 'TeleMed_K',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: screen,
      debugShowCheckedModeBanner: false,
    );
  }
}
