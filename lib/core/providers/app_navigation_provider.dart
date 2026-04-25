// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'medical_session_provider.dart';

enum AppRoute {
  home,
  confirmation,
  emergency,
  history,
  myDoctor,
  waitingRoom,
  videoConsultation,
  loginIdentity,
  loginVerification,
  modelDownload,
}

class AppNavigationNotifier extends Notifier<AppRoute> {
  // Set by main() before runApp when the model file is absent on disk.
  // Causes the first screen shown to be ModelDownloadScreen instead of login.
  // Resets to false once the user reaches loginIdentity after a successful download.
  static bool needsModelDownload = false;

  @override
  AppRoute build() {
    ref.listen<SessionState>(medicalSessionProvider, (previous, next) {
      final currentState = state;
      if (currentState == AppRoute.loginIdentity ||
          currentState == AppRoute.loginVerification ||
          currentState == AppRoute.modelDownload) {
        return;
      }
      if (next == SessionState.emergency) {
        state = AppRoute.emergency;
      } else if (next == SessionState.success) {
        state = AppRoute.confirmation;
      } else if (next == SessionState.idle) {
        state = AppRoute.home;
      }
    });
    return needsModelDownload ? AppRoute.modelDownload : AppRoute.loginIdentity;
  }

  void navigateTo(AppRoute route) {
    state = route;
  }
}

final appNavigationProvider =
    NotifierProvider<AppNavigationNotifier, AppRoute>(() {
  return AppNavigationNotifier();
});
