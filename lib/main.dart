// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_navigation_provider.dart';
import 'data/repositories/fhir_repository.dart';
import 'ui/theme/theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/confirmation_screen.dart';
import 'ui/screens/emergency_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/my_doctor_screen.dart';
import 'ui/screens/waiting_room_screen.dart';
import 'ui/screens/video_consultation_screen.dart';
import 'ui/screens/login_identity_screen.dart';
import 'ui/screens/login_verification_screen.dart';

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
    // Dynamic routing relying strictly on AppNavigationNotifier mappings overrides 
    // triggered by AI logic constraints.
    final currentRoute = ref.watch(appNavigationProvider);

    Widget screen;
    switch (currentRoute) {
      case AppRoute.emergency:
        screen = const EmergencyScreen();
        break;
      case AppRoute.confirmation:
        screen = const ConfirmationScreen();
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
    }

    return MaterialApp(
      title: 'TeleMed_K',
      theme: AppTheme.lightTheme,
      home: screen,
      debugShowCheckedModeBanner: false,
    );
  }
}
