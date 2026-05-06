// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';

import '../constants/practitioner_constants.dart';

/// Represents a medical specialty available in the Specialiști screen.
///
/// [appStringKey]    — AppStrings key for the localized specialty name.
/// [icon]            — Material icon representing the specialty.
/// [practitionerRef] — Placeholder FHIR Practitioner ID (MVP); Medplum wires real IDs.
class Specialty {
  final String appStringKey;
  final IconData icon;
  final String practitionerRef;

  const Specialty({
    required this.appStringKey,
    required this.icon,
    required this.practitionerRef,
  });

  /// Canonical specialty list from Stitch ground-truth dump (A0).
  static const List<Specialty> allSpecialties = [
    Specialty(
      appStringKey:    'specialist.cardiologie',
      icon:            Icons.favorite,
      practitionerRef: Practitioners.cardioId,
    ),
    Specialty(
      appStringKey:    'specialist.neurologie',
      icon:            Icons.psychology,
      practitionerRef: Practitioners.neuroId,
    ),
    Specialty(
      appStringKey:    'specialist.dermatologie',
      icon:            Icons.face,
      practitionerRef: Practitioners.dermId,
    ),
    Specialty(
      appStringKey:    'specialist.ortopedie',
      icon:            Icons.accessibility_new,
      practitionerRef: Practitioners.orthoId,
    ),
    Specialty(
      appStringKey:    'specialist.oftalmologie',
      icon:            Icons.visibility,
      practitionerRef: Practitioners.ophthaId,
    ),
    Specialty(
      appStringKey:    'specialist.pediatrie',
      icon:            Icons.child_care,
      practitionerRef: Practitioners.bogheanuId,
    ),
    Specialty(
      appStringKey:    'specialist.psihiatrie',
      icon:            Icons.self_improvement,
      practitionerRef: Practitioners.psychId,
    ),
    Specialty(
      appStringKey:    'specialist.ginecologie',
      icon:            Icons.pregnant_woman,
      practitionerRef: Practitioners.gyneId,
    ),
  ];
}
