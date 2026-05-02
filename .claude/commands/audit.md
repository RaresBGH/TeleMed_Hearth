# Code Audit Command
When auditing the TeleMed_K codebase, check these in order:

1. FLUTTER COMPATIBILITY — Flag any Dart/Flutter APIs that are not available in Flutter stable 3.32.x. The CI runs stable, local dev runs master 3.44.0. Any master-only APIs will break CI builds.

2. DEAD CODE — List any files, classes, methods, or providers that are imported but never used, or screens that are defined but never navigated to.

3. DUPLICATE LOGIC — Find any business logic duplicated across files (e.g. FHIR writes, CNP validation, model path lookup) that should be in a single service.

4. BROKEN REFERENCES — Find any import paths, method calls, or MethodChannel method names that don't match their definitions.

5. STATE MANAGEMENT CONSISTENCY — Check that all state is managed via Riverpod providers, not via setState or global variables except where intentional (e.g. LiteRtLmChannel static fields).

6. APPSTRINGS COVERAGE — Find any hardcoded Romanian or English strings in UI files that are not routed through AppStrings.

7. ERROR HANDLING GAPS — Find any async calls (FHIR, inference, audio, camera) that have no try/catch or fallback.

Report findings as a numbered list per category. Severity: CRITICAL (breaks build or crashes), HIGH (data loss or wrong behavior), MEDIUM (code smell), LOW (style). Fix nothing — report only.

FINISH MESSAGE: "AUDIT_COMPLETE — critical: N — high: N — medium: N — low: N"
