// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

/// Shared ISO 8601 date/time formatter used across the app.
class DateFormatter {
  DateFormatter._();

  /// Formats an ISO 8601 [iso] string.
  ///
  /// Without time (default): "DD.MM.YYYY"  — returns '' on empty/invalid.
  /// With time: "DD.MM.YYYY  HH:mm"        — returns 'Dată recentă' on empty/invalid.
  static String format(String iso, {bool includeTime = false}) {
    if (iso.isEmpty) return includeTime ? 'Dată recentă' : '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return includeTime ? 'Dată recentă' : iso;
    final d   = dt.day.toString().padLeft(2, '0');
    final m   = dt.month.toString().padLeft(2, '0');
    if (!includeTime) return '$d.$m.${dt.year}';
    final h   = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year}  $h:$min';
  }
}
