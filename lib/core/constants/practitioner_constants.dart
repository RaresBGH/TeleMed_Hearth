// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

/// Real Medplum Practitioner IDs and display names.
/// Seeded in TeleMed Bogheanu project (ID: 7b4bc928-abd8-4332-b6f5-a9cae5737fa8).
class Practitioners {
  Practitioners._();

  static const familyDoctorId =
      'Practitioner/733e1972-b42d-4bd0-82c7-66db72b2d311';
  /// Bare UUID without the 'Practitioner/' prefix — use when APIs expect the raw ID.
  static String get familyDoctorBareId =>
      familyDoctorId.replaceFirst('Practitioner/', '');
  static const familyDoctorName = 'Dr. Elena Ionescu';
  // Reserved for future use in specialty display.
  static const familyDoctorSpecialty = 'Medic de Familie';

  static const bogheanuId =
      'Practitioner/474f526b-7919-48dd-9528-3c0eaff80cb6';
  // Named after clinic (Bogheanu) but value is Dr. Andrei Popescu — the resident specialist.
  // Do not rename the constant — it is referenced in multiple places.
  static const bogheanuName = 'Dr. Andrei Popescu';
  // Reserved for future use in specialty display.
  static const bogheanuSpecialty = 'Pediatrie';

  // ── Specialist mock names ──────────────────────────────────────────────────
  static const cardioName  = 'Dr. Ioan Petrescu';
  static const neuroName   = 'Dr. Mihai Dumitrescu';
  static const dermName    = 'Dr. Cristina Florescu';
  static const orthoName   = 'Dr. Radu Constantin';
  static const ophthaName  = 'Dr. Anca Mureșan';
  static const psychName   = 'Dr. Sorin Nistor';
  static const gyneName    = 'Dr. Luminița Gheorghe';

  // ── Specialist Medplum UUIDs ───────────────────────────────────────────────
  static const cardioId  = 'Practitioner/89b433f1-6c1d-41c3-bba8-f0e62011f86d';
  static const neuroId   = 'Practitioner/1eb50655-492c-4e65-9e9c-3c4c52592ca4';
  static const dermId    = 'Practitioner/da372669-0950-4e0c-8e1a-cc24f667b3df';
  static const orthoId   = 'Practitioner/7cd1e41c-c484-4873-8d1d-22ec6af86e51';
  static const ophthaId  = 'Practitioner/45965f71-a4e1-43cc-a0f9-532fc84b9e24';
  static const psychId   = 'Practitioner/94fcc35d-7fcd-4773-ab0f-5f5974435762';
  static const gyneId    = 'Practitioner/c9e9b208-ace2-4b87-b8ea-0c366b194b80';

  // ── Entitlement strings ────────────────────────────────────────────────────
  static const familyDoctorEntitlement = 'Consultant Family Physician';
  static const bogheanuEntitlement     = 'Specialist Pediatrician';
  static const cardioEntitlement       = 'Specialist Cardiologist';
  static const neuroEntitlement        = 'Specialist Neurologist';
  static const dermEntitlement         = 'Specialist Dermatologist';
  static const orthoEntitlement        = 'Specialist Orthopedic Surgeon';
  static const ophthaEntitlement       = 'Specialist Ophthalmologist';
  static const psychEntitlement        = 'Specialist Psychiatrist';
  static const gyneEntitlement         = 'Specialist Gynecologist';
}
