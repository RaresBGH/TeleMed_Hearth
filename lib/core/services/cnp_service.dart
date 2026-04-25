// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

/// Utilities for Romanian CNP (Cod Numeric Personal) validation and parsing.
///
/// CNP structure (1-indexed):
///   1        — S: gender + century indicator (1-9)
///   2-3      — AA: birth year last two digits (YY)
///   4-5      — LL: birth month (MM, 01-12)
///   6-7      — ZZ: birth day (DD, 01-31)
///   8-9      — JJ: county code (01-46, 51-52, 99)
///   10-12    — NNN: sequence number within county/day
///   13       — C: checksum digit
///
/// S encoding:
///   1,2 → born 1900-1999  |  3,4 → born 1800-1899
///   5,6 → born 2000-2099  |  7,8 → foreign residents with permit (20xx)
///   9   → non-residents (year not encoded in CNP)
///
/// ⚠ DEMO MODE: [extractDemoOtp] derives the OTP from the CNP locally.
/// In production, OTPs are sent via SMS gateway. See README § Autentificare Demo.
class CnpService {
  CnpService._(); // static-only class

  // Control weights for positions 1-12 (0-indexed: 0-11)
  static const _weights = [2, 7, 9, 1, 4, 6, 3, 5, 8, 2, 7, 9];

  // Valid county codes (integers) per official ANCPI list.
  // 47-50 are unassigned and invalid. 99 = foreign resident.
  static const _validCounties = {
    1,  2,  3,  4,  5,  6,  7,  8,  9,  10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46,
    51, 52, // Călărași, Giurgiu
    99,     // foreign residents
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  //
  // Valid test CNP (generated, not real): 1850415150017
  //   S=1  → male, born 1900-1999
  //   AA=85 → 1985
  //   LL=04 → April   (valid: 01-12) ✓
  //   ZZ=15 → 15th    (valid: 01-31) ✓
  //   JJ=15 → Dâmbovița county       ✓
  //   NNN=001
  //   Checksum: 1*2+8*7+5*9+0*1+4*4+1*6+5*3+1*5+5*8+0*2+0*7+1*9
  //           = 2+56+45+0+16+6+15+5+40+0+0+9 = 194
  //           194 % 11 = 7 → C=7   ✓  (full CNP: 1850415150017)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if [cnp] is a syntactically and structurally valid Romanian CNP.
  /// Never throws — returns false on any parsing failure.
  static bool isValid(String cnp) {
    try {
      // Rule 1: exactly 13 decimal digits, no spaces
      final cleaned = cnp.trim();
      if (cleaned.length != 13) return false;
      if (!RegExp(r'^\d{13}$').hasMatch(cleaned)) return false;

      final digits = cleaned.split('').map(int.parse).toList();

      // Rule 2: S (first digit) must be 1-9
      if (digits[0] < 1 || digits[0] > 9) return false;

      // Rule 3: month must be 01-12
      final month = digits[3] * 10 + digits[4];
      if (month < 1 || month > 12) return false;

      // Rule 4: day must be 01-31
      final day = digits[5] * 10 + digits[6];
      if (day < 1 || day > 31) return false;

      // Rule 5: county code JJ must be in the valid set
      final county = digits[7] * 10 + digits[8];
      if (!_validCounties.contains(county)) return false;

      // Rule 6: checksum — multiply digits 1-12 by weights, sum, mod 11
      // Remainder 10 → stored as 1; otherwise stored as-is
      int sum = 0;
      for (int i = 0; i < 12; i++) {
        sum += digits[i] * _weights[i];
      }
      final remainder = sum % 11;
      final checkDigit = remainder == 10 ? 1 : remainder;
      if (digits[12] != checkDigit) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Age validation
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if the person encoded in [cnp] is at least 18 years old.
  /// Only call after [isValid] returns true.
  /// S=9 (non-resident, year not encoded) → returns true (cannot verify, assume adult).
  static bool isAdult(String cnp) {
    try {
      final yearStr = getBirthYear(cnp);
      if (yearStr == 'N/A') return true; // non-resident — age unknown, allow

      final year  = int.parse(yearStr);
      final month = int.parse(cnp.substring(3, 5));
      final day   = int.parse(cnp.substring(5, 7));

      final birthDate = DateTime(year, month, day);
      final age18     = DateTime(year + 18, month, day);
      return !DateTime.now().isBefore(age18);
    } catch (_) {
      return false;
    }
  }

  /// Returns a Romanian error message if the person is under 18, null if adult.
  /// Only call after [isValid] returns true.
  static String? getAgeError(String cnp) {
    if (!isAdult(cnp)) {
      return 'Vârsta minimă pentru utilizarea acestui serviciu este de 18 ani.';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo OTP derivation
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the last 6 digits of the CNP (positions 7-12, 0-indexed) as the demo OTP.
  /// Only call after [isValid] returns true.
  /// Last 6 digits: CNP 1850415150017 → OTP: 150017
  ///
  /// ⚠ DEMO ONLY — not secure for production. Replace with SMS gateway.
  static String extractDemoOtp(String cnp) => cnp.substring(7, 13);

  // ─────────────────────────────────────────────────────────────────────────
  // Identity helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a masked birth-date string to reassure the patient without
  /// exposing personal data. Format: "MMXX / CCXX"
  /// e.g. CNP born July 1985 → "07XX / 19XX"
  static String maskPhone(String cnp) {
    final month = cnp.substring(3, 5);
    final century = _centuryPrefix(cnp);
    return '${month}XX / ${century}XX';
  }

  /// Returns the full 4-digit birth year decoded from the CNP.
  /// S=9 (non-resident) → returns 'N/A' since year is not encoded.
  static String getBirthYear(String cnp) {
    if (int.parse(cnp[0]) == 9) return 'N/A';
    final yy = cnp.substring(1, 3);
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
      case 9:
        return 'N/A';
      default:
        return '19';
    }
  }
}
