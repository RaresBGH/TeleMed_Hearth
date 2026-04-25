# TeleMed_K — Codebase Audit Request

You are performing a complete codebase audit of TeleMed_K, a Flutter 
telemedicine application for rural Romania. Read TELEMED_CONTEXT.md 
and DESIGN.md first before auditing anything.

Do NOT make any changes. Do NOT commit anything. Audit only.

Report the following sections in order:

## 1. Stack & Dependencies
- Framework, language, Flutter version, Dart version
- Every dependency in pubspec.yaml with version and actual role
- Every Gradle dependency in build.gradle.kts with version and role
- Flag any deprecated, discontinued, or community-fork packages
- Flag any version aliases (e.g. latest.release) that should be pinned

## 2. Project Structure
- Full directory tree to 3 levels
- Purpose of each directory

## 3. Screens Inventory
For every file in lib/ui/screens/ and lib/ui/widgets/:
- Filename
- Purpose
- Completion status: COMPLETE / PARTIAL / STUB / BROKEN
- Specific broken elements (exact method names, line numbers)
- Whether it matches a Stitch design in stitch_telemed_k/ folder

## 4. Services & Providers Inventory
For every file in lib/core/services/ and lib/core/providers/:
- Filename and purpose
- What is real vs stub vs dummy
- Any hardcoded values that must change before production
  (IPs, client_ids, file paths, URLs)

## 5. Native Android Layer
For every Kotlin file in android/app/src/main/kotlin/:
- Filename and purpose
- MethodChannel contract: what methods it handles, exact signatures
- Whether the Dart side calls match the Kotlin side handles
- Any channel name mismatches

## 6. AI Integration Status
- Is the LiteRT-LM Engine ever instantiated?
- Is initializeModel() called and from where?
- What is the exact model file path the Kotlin side looks for?
- What is the exact model file path the Dart side passes?
- Do they match?
- Is the model file present on disk? Check both:
    /sdcard/Download/gemma-4-E2B-it.litertlm
    context.filesDir/models/gemma-4-E2B-it.litertlm

## 7. Routing & Navigation
- What is the initial route?
- Is there any listener that can override the initial route on startup?
- List every AppRoute value and which screen it maps to
- Are there any unreachable screens?

## 8. Backend & Auth
- What endpoints does the app call?
- Are any credentials hardcoded? (client_id, tokens, IPs)
- Is Medplum auth functional or stub?
- Is there any real SMS/OTP service configured?

## 9. Assets & Localization
- Are all user-facing strings in Romanian?
- Is Lexend font loading correctly via google_fonts?
- Are there any hardcoded English strings in UI code?
- Is the DESIGN.md color system (#5BA4CF primary, #ab1118 tertiary) 
  applied consistently?

## 10. Build Status
- Result of: flutter analyze (exact error and warning count)
- Last known CI result and commit hash
- Any dependency that caused previous CI failures
- List any file with TODO or FIXME comments

## 11. Device State (from TELEMED_CONTEXT.md)
- What is confirmed working on the Pixel 9 Pro test device?
- What has never been tested on device?
- What failed on device and why?

## 12. Honest Priority Assessment
Given the hackathon deadline (May 18, 2026), list every remaining 
task as:
- P0: blocks the demo entirely
- P1: needed for a credible demo
- P2: nice to have
- P3: post-hackathon

For each task estimate effort in hours honestly.

Print "AUDIT COMPLETE — [date] — [total issues found]" at the end.
