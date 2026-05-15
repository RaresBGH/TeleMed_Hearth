// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the active UI/AI language code: "en" (English, default) or "ro" (Romanian).
class LanguageNotifier extends Notifier<String> {
  @override
  String build() => 'en';

  void setLanguage(String lang) => state = lang;
}

final languageProvider =
    NotifierProvider<LanguageNotifier, String>(LanguageNotifier.new);
