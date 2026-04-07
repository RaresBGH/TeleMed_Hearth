// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Temporarily stores the CNP entered on the Identity Screen
/// so it can be used on the Verification Screen.
class LoginCnpNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setCnp(String cnp) {
    state = cnp;
  }
}

final loginCnpProvider = NotifierProvider<LoginCnpNotifier, String>(() {
  return LoginCnpNotifier();
});
