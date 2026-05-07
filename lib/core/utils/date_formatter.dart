// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';

/// Shared ISO 8601 date/time formatter used across the app.
class DateFormatter {
  DateFormatter._();

  /// Formats an ISO 8601 [iso] string.
  ///
  /// Without time (default): "DD.MM.YYYY"  — returns '' on empty/invalid.
  /// With time: "DD.MM.YYYY  HH:mm"        — returns 'Recent Health Status' on empty/invalid.
  static String format(String iso, {bool includeTime = false}) {
    if (iso.isEmpty) return includeTime ? 'Recent Health Status' : '';
    final dtUtc = DateTime.tryParse(iso);
    if (dtUtc == null) return includeTime ? 'Recent Health Status' : iso;
    // Convert to device local time so stored UTC appointment times display correctly.
    final dt  = dtUtc.toLocal();
    final d   = dt.day.toString().padLeft(2, '0');
    final m   = dt.month.toString().padLeft(2, '0');
    if (!includeTime) return '$d.$m.${dt.year}';
    final h   = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year}  $h:$min';
  }

  /// Formats a [TimeOfDay] as "HH:mm".
  static String formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formats a [Duration] as "MM:SS" (minutes and seconds within an hour).
  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Formats raw [hour] and [minute] integers as "HH:mm".
  static String formatTimeOfDay(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
