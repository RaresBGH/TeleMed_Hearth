// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import '../l10n/app_strings.dart';

/// Returns a canonical status key for display + color purposes.
///
/// One of: 'booked' (confirmed/future), 'fulfilled' (finalized), 'postponed', 'cancelled'.
///
/// Derivation rules:
/// - fulfilled/cancelled/noshow → mapped directly to canonical form.
/// - booked/confirmed + future (within 5-min grace after end) → 'booked'.
/// - booked/confirmed + past, ≥1 Observation effectiveDateTime within ±2hr of start → 'fulfilled'.
/// - booked/confirmed + past, no matching Observation → 'postponed'.
String deriveStatusCode(
  Map<String, dynamic> appt,
  List<Map<String, dynamic>> observations,
) {
  final rawStatus = (appt['status'] as String? ?? '').toLowerCase();

  // Terminal statuses: pass through directly.
  if (rawStatus == 'fulfilled') return 'fulfilled';
  if (rawStatus == 'cancelled') return 'cancelled';
  if (rawStatus == 'noshow') return 'cancelled';

  // For everything other than 'booked'/'confirmed', treat as confirmed.
  if (rawStatus != 'booked' && rawStatus != 'confirmed') return 'booked';

  final startIso = appt['start'] as String? ?? '';
  if (startIso.isEmpty) return 'booked';
  final start = DateTime.tryParse(startIso)?.toLocal();
  if (start == null) return 'booked';

  // Compute effective end: use stored end or assume 30-minute slot.
  final endIso = appt['end'] as String?;
  final end = endIso != null ? DateTime.tryParse(endIso)?.toLocal() : null;
  final effectiveEnd = end ?? start.add(const Duration(minutes: 30));
  final pastThreshold = effectiveEnd.add(const Duration(minutes: 5));

  if (DateTime.now().isBefore(pastThreshold)) return 'booked'; // future or in-progress

  // Appointment is in the past — check for a linked Observation by time proximity.
  const matchWindow = Duration(hours: 2);
  final hasMatchingObs = observations
      .where((obs) => obs['resourceType'] == 'Observation')
      .any((obs) {
        final obsDateStr =
            obs['effectiveDateTime'] as String? ??
            obs['recordedDate'] as String? ??
            '';
        if (obsDateStr.isEmpty) return false;
        final obsDate = DateTime.tryParse(obsDateStr)?.toLocal();
        if (obsDate == null) return false;
        return obsDate.difference(start).abs() <= matchWindow;
      });

  return hasMatchingObs ? 'fulfilled' : 'postponed';
}

/// Returns the localized display label for an appointment, using client-side
/// derivation rather than the raw FHIR Appointment.status field.
String deriveDisplayStatus(
  Map<String, dynamic> appt,
  List<Map<String, dynamic>> observations,
  String lang,
) {
  switch (deriveStatusCode(appt, observations)) {
    case 'fulfilled':  return AppStrings.of(lang, 'appt.status_finalized');
    case 'cancelled':  return AppStrings.of(lang, 'appt.status_cancelled');
    case 'postponed':  return AppStrings.of(lang, 'appt.status_postponed');
    default:           return AppStrings.of(lang, 'appt.status_confirmed');
  }
}
