// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

/// Utilities for Romanian CNP (Cod Numeric Personal) validation and parsing.
///
/// CNP structure (1-indexed):
///   1        — gender + century indicator (1-8)
///   2-3      — birth year (YY)
///   4-5      — birth month (MM)
///   6-7      — birth day (DD)
///   8-9      — county code (01-46, 51-52)
///   10-12    — sequence number within county/day
///   13       — checksum digit
///
/// ⚠ DEMO MODE: [extractDemoOtp] derives the OTP from the CNP locally.
/// In production, OTPs are sent via SMS gateway. See README § Autentificare Demo.
class CnpService {
  CnpService._(); // static-only class

  // ─────────────────────────────────────────────────────────────────────────
  // Valid Romanian county codes (official ANCPI list)
  // 47-50 are unassigned and invalid.
  // ─────────────────────────────────────────────────────────────────────────
  static const _validCountyCodes = {
    '01', '02', '03', '04', '05', '06', '07', '08', '09', '10',
    '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
    '21', '22', '23', '24', '25', '26', '27', '28', '29', '30',
    '31', '32', '33', '34', '35', '36', '37', '38', '39', '40',
    '41', '42', '43', '44', '45', '46',
    '51', '52', // Călărași, Giurgiu
  };

  // Checksum weights for digits 1-12 (0-indexed: positions 0-11)
  static const _weights = [2, 7, 9, 1, 4, 6, 3, 5, 8, 2, 7, 9];

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if [cnp] is a syntactically and structurally valid Romanian CNP.
  /// Never throws — returns false on any parsing failure.
  static bool isValid(String cnp) {
    try {
      // Must be exactly 13 decimal digits
      if (cnp.length != 13) return false;
      if (!RegExp(r'^\d{13}$').hasMatch(cnp)) return false;

      // First digit encodes gender+century: valid values are 1-8
      final firstDigit = int.parse(cnp[0]);
      if (firstDigit < 1 || firstDigit > 8) return false;

      // County code: positions 8-9 (0-indexed 7-8)
      final countyCode = cnp.substring(7, 9);
      if (!_validCountyCodes.contains(countyCode)) return false;

      // Checksum: multiply digits 1-12 by weights, sum, mod 11
      // Result 10 → stored as 1; otherwise stored as-is
      int sum = 0;
      for (int i = 0; i < 12; i++) {
        sum += int.parse(cnp[i]) * _weights[i];
      }
      final remainder = sum % 11;
      final expected = remainder == 10 ? 1 : remainder;
      if (int.parse(cnp[12]) != expected) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo OTP derivation
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns digits 7-12 of the CNP (0-indexed: substring(6, 12)) as the
  /// demo OTP. Only call after [isValid] returns true.
  ///
  /// ⚠ DEMO ONLY — not secure for production. Replace with SMS gateway.
  static String extractDemoOtp(String cnp) => cnp.substring(6, 12);

  // ─────────────────────────────────────────────────────────────────────────
  // Identity helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a masked birth-date string to reassure the patient without
  /// exposing personal data. Format: "MMXX / CCXX"
  /// e.g. CNP born July 1985 → "07XX / 19XX"
  static String maskPhone(String cnp) {
    final month = cnp.substring(3, 5); // digits 4-5 (MM)
    final century = _centuryPrefix(cnp);
    return '${month}XX / ${century}XX';
  }

  /// Returns the full 4-digit birth year decoded from the CNP.
  /// Digit 1 determines century:
  ///   1,2 → 1900s | 3,4 → 1800s | 5,6 → 2000s | 7,8 → resident foreigner (20xx)
  static String getBirthYear(String cnp) {
    final yy = cnp.substring(1, 3); // digits 2-3
    return '${_centuryPrefix(cnp)}$yy';
  }

  static String _centuryPrefix(String cnp) {
    switch (int.parse(cnp[0])) {
      case 1:
      case 2:
        return '19';
      case 3:
      case 4:
        return '18';
      case 5:
      case 6:
      case 7:
      case 8:
        return '20';
      default:
        return '19';
    }
  }
}
