// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/providers/app_navigation_provider.dart';
import 'core/services/ai_engine_service.dart';
import 'data/repositories/fhir_repository.dart';
import 'ui/theme/theme.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/emergency_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/model_download_screen.dart';
import 'ui/screens/my_doctor_screen.dart';
import 'ui/screens/waiting_room_screen.dart';
import 'ui/screens/video_consultation_screen.dart';
import 'ui/screens/login_identity_screen.dart';
import 'ui/screens/login_verification_screen.dart';
import 'ui/screens/medical_response_screen.dart';
import 'ui/screens/appointments_screen.dart';
import 'ui/screens/patient_profile_screen.dart';
import 'ui/screens/specialists_screen.dart';
import 'ui/screens/profile_completion_screen.dart';
import 'core/providers/medical_session_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required for TableCalendar to render Romanian month/weekday names.
  await initializeDateFormatting('ro_RO', null);

  // Initialize the local FHIR engine (encrypted SQLite) and seed mock data
  // before the widget tree renders. Must run after ensureInitialized() because
  // it uses a MethodChannel to talk to the native Android FHIR SDK.
  // Direct instantiation is intentional here: ProviderScope does not yet exist
  // at this point in main(), so ref.read(fhirRepositoryProvider) is unavailable.
  final fhirRepo = FhirRepository();
  try {
    await fhirRepo.initialize();
  } catch (_) {
    // Non-fatal during development when running on host without the native
    // Android FHIR SDK (e.g. flutter test on desktop).
  }

  // If model is already on disk, start loading it in background while the
  // user completes login. Navigation to the download screen now happens
  // after successful OTP verification, not here.
  if (await AiEngineService.isModelOnDisk()) {
    unawaited(AiEngineService(fhirRepo).initializeModel());
  }

  runApp(
    const ProviderScope(
      child: TeleMedApp(),
    ),
  );
}

class TeleMedApp extends ConsumerWidget {
  const TeleMedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = ref.watch(appNavigationProvider);

    Widget screen;
    switch (currentRoute) {
      case AppRoute.dashboard:
        screen = const DashboardScreen();
        break;
      case AppRoute.modelDownload:
        screen = const ModelDownloadScreen();
        break;
      case AppRoute.emergency:
        screen = const EmergencyScreen();
        break;
      case AppRoute.medicalResponse:
        final msState = ref.read(medicalSessionProvider);
        screen = MedicalResponseScreen(
          initialResponse:
              msState.lastAiResponse ?? 'Simptomele au fost înregistrate.',
          isEmergency: msState.lastIsEmergency,
          initialMessages: msState.lastResumeMessages,
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
      case AppRoute.patientProfile:
        screen = const PatientProfileScreen();
        break;
      case AppRoute.appointments:
        screen = const AppointmentsScreen();
        break;
      case AppRoute.specialists:
        screen = const SpecialistsScreen();
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
