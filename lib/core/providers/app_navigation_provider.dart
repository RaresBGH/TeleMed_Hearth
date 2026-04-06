// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'medical_session_provider.dart';

enum AppRoute { home, confirmation, emergency, history, myDoctor, waitingRoom, videoConsultation }

class AppNavigationNotifier extends Notifier<AppRoute> {
  @override
  AppRoute build() {
    ref.listen<SessionState>(medicalSessionProvider, (previous, next) {
      if (next == SessionState.emergency) {
        state = AppRoute.emergency;
      } else if (next == SessionState.success) {
        state = AppRoute.confirmation;
      } else if (next == SessionState.idle) {
        state = AppRoute.home;
      }
    });
    return AppRoute.home;
  }

  void navigateTo(AppRoute route) {
    state = route;
  }
}

final appNavigationProvider = NotifierProvider<AppNavigationNotifier, AppRoute>(() {
  return AppNavigationNotifier();
});
