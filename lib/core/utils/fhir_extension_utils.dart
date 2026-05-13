// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

/// Canonical FHIR extension URLs and matching helpers.
/// All extension reads across the app should use these helpers
/// to ensure a consistent matching strategy.
class FhirExtensionUtils {
  FhirExtensionUtils._();

  static const String sessionCategoryUrl =
      'https://telemed-bogheanu.ro/fhir/ext/session-category';
  static const String reviewedByTargetUrl =
      'https://telemed-bogheanu.ro/fhir/ext/reviewed-by-target';
  static const String reviewedByUrl =
      'https://telemed-bogheanu.ro/fhir/ext/reviewed-by';
  static const String doctorNameUrl =
      'https://telemed-bogheanu.ro/fhir/ext/doctor-name';
  /// Bare (non-FHIR-domain) URL for the isPatient Communication extension.
  static const String isPatientUrl = 'isPatient';

  static bool isSessionCategory(String url) => url.endsWith('session-category');
  // Used by doctor-ui/index.html JS reader only.
  // Kept as documentation of the extension contract.
  static bool isReviewedByTarget(String url) => url.endsWith('reviewed-by-target');
  // Used by doctor-ui/index.html JS reader only.
  // Kept as documentation of the extension contract.
  static bool isReviewedBy(String url) => url.endsWith('reviewed-by');
  static bool isDoctorName(String url) => url.endsWith('doctor-name');
}
