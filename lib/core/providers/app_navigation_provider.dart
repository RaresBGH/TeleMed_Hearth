// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'medical_session_provider.dart';

enum AppRoute {
  home,
  confirmation,
  medicalResponse,
  emergency,
  history,
  myDoctor,
  waitingRoom,
  videoConsultation,
  loginIdentity,
  loginVerification,
  modelDownload,
  profileCompletion,
}

class AppNavigationNotifier extends Notifier<AppRoute> {
  @override
  AppRoute build() {
    ref.listen<SessionState>(medicalSessionProvider, (previous, next) {
      final currentState = state;
      // Don't interrupt auth or download flows with session-state changes.
      if (currentState == AppRoute.loginIdentity ||
          currentState == AppRoute.loginVerification ||
          currentState == AppRoute.modelDownload ||
          currentState == AppRoute.profileCompletion) {
        return;
      }
      if (next == SessionState.emergency) {
        state = AppRoute.emergency;
      } else if (next == SessionState.success) {
        state = AppRoute.medicalResponse;
      } else if (next == SessionState.idle) {
        state = AppRoute.home;
      }
    });
    // Always start at login — model check happens after successful OTP.
    return AppRoute.loginIdentity;
  }

  void navigateTo(AppRoute route) {
    state = route;
  }
}

final appNavigationProvider =
    NotifierProvider<AppNavigationNotifier, AppRoute>(() {
  return AppNavigationNotifier();
});
