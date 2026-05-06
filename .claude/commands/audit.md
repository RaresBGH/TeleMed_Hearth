# Code Audit Command
When auditing the TeleMed_K codebase, check these in order:

1. FLUTTER COMPATIBILITY — Flag any Dart/Flutter APIs that are not available in Flutter stable 3.32.x. The CI runs stable, local dev runs master 3.44.0. Any master-only APIs will break CI builds.

2. DEAD CODE — List any files, classes, methods, or providers that are imported but never used, or screens that are defined but never navigated to.

3. DUPLICATE LOGIC — Find any business logic duplicated across files (e.g. FHIR writes, CNP validation, model path lookup) that should be in a single service.

4. BROKEN REFERENCES — Find any import paths, method calls, or MethodChannel method names that don't match their definitions.

5. STATE MANAGEMENT CONSISTENCY — Check that all state is managed via Riverpod providers, not via setState or global variables except where intentional (e.g. LiteRtLmChannel static fields).

6. APPSTRINGS COVERAGE — Find any hardcoded Romanian or English strings in UI files that are not routed through AppStrings.

7. ERROR HANDLING GAPS — Find any async calls (FHIR, inference, audio, camera, Medplum REST) that have no try/catch or fallback.

8. SECURITY — Check for:
   - Hardcoded secrets or credentials in Dart files (client secrets, passwords, API keys)
   - Any token or credential logged via print() or log() calls
   - flutter_secure_storage used correctly for all sensitive values (tokens, secrets never in SharedPreferences)
   
   - Check that patientAvatarProvider (NotifierProvider<Uint8List?>) never 
     persists avatar bytes to disk unencrypted — bytes must live in memory 
     only, never written to SharedPreferences or plain files.

9. RESOURCE DISPOSAL — Check for:
   - AnimationController, TextEditingController, ScrollController, StreamSubscription declared in State classes but missing dispose() calls
   - Any timer (Timer.periodic) not cancelled in dispose()

10. ANDROID PERMISSIONS — Verify AndroidManifest.xml declares every permission actually used in code:
    - INTERNET (Medplum REST, model download)
    - RECORD_AUDIO (microphone)
    - CAMERA
    - READ_EXTERNAL_STORAGE / READ_MEDIA_* (image picker)
    - FOREGROUND_SERVICE (model download service)
    - RECEIVE_BOOT_COMPLETED (if used)
    Flag any permission used in code but missing from manifest, and any declared but never used.

11. NETWORK SECURITY — Verify:
    - network_security_config.xml exists and restricts cleartext traffic
    - Only explicitly allowed domains permit cleartext (none should — all three endpoints use HTTPS)
    - usesCleartextTraffic in manifest is false or absent
    
12. FHIR EXTENSION URL CONSISTENCY — Verify that extension URLs written 
    by Flutter (finalizeConsultation, setDoctorContext) match exactly 
    what the doctor UI JavaScript reads in doctor-ui/index.html. 
    Specifically check these three URLs for exact string match between 
    writer and reader:
      - https://telemed-bogheanu.ro/fhir/ext/reviewed-by-target
      - https://telemed-bogheanu.ro/fhir/ext/reviewed-by
      - https://telemed-bogheanu.ro/fhir/ext/session-category
    Also verify the audio/photo attachment serialization format written 
    by finalizeConsultation ([Voice:/path] and [Photo:/path]) matches 
    exactly what _parseNoteToMessages in dialog_detail_sheet.dart expects.
    Report any mismatch as CRITICAL.

Report findings as a numbered list per category. Severity: CRITICAL (breaks build or crashes), HIGH (data loss or wrong behavior), MEDIUM (code smell), LOW (style). Fix nothing — report only.

Files to include in audit scope (explicitly):
  lib/core/services/medplum_auth_service.dart
  lib/core/services/medplum_repository.dart
  lib/core/providers/medplum_auth_provider.dart
  lib/core/constants/practitioner_constants.dart
  All other files under lib/
  android/app/src/main/AndroidManifest.xml
  android/app/src/main/res/xml/network_security_config.xml (if exists)

FINISH MESSAGE: "AUDIT_COMPLETE — critical: N — high: N — medium: N — low: N"
