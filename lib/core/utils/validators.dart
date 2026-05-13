// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

/// Shared input validators used across login, profile, and voice-extraction flows.
class Validators {
  Validators._();

  /// Returns true if [value] is a valid Romanian mobile number (07XXXXXXXX, 10 digits).
  static bool isValidRomanianPhone(String value) =>
      RegExp(r'^07\d{8}$').hasMatch(value);
}
