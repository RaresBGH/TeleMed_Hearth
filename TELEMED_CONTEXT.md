# TeleMed_K — Project Context for AI Assistant
Last updated: 2026-04-25

## What This Is
Flutter telemedicine app for rural Romania. MVP for Dr. Bogheanu's clinic in Brănești, Dâmbovița.
Competition: Kaggle Gemma 4 Good Hackathon — deadline May 18, 2026 (23 days remaining).
Repo: https://github.com/RaresBGH/TeleMed_K (currently PRIVATE — must make public before deadline)

## Owner
Rareș Bogheanu (RaresBGH) — QA engineer, 20 years experience, owns medical clinic Dr. Bogheanu in Brănești.
NGO provides devices + digital literacy to elderly patients who cannot afford good enough smartphones.

---

## Tech Stack

**Framework:** Flutter (Dart) + Android native (Kotlin). Android-only target.
**Flutter:** 3.44.0 master channel (snap, /snap/bin/flutter). Dart SDK 3.13.0.
**Android SDK:** ~/Android/Sdk. compileSdk=36, minSdk=28 (Android 9+), JVM 17.
**Build:** GitHub Actions CI (ubuntu-latest x86_64, Flutter 3.32.x stable) → debug APK artifact.
**Java:** /usr/bin/java (17). ADB: /usr/lib/android-sdk/platform-tools/adb (ARM64 build).

### Flutter dependencies (pubspec.yaml)
| Package | Version | Role |
|---|---|---|
| flutter_riverpod | ^3.3.1 | State management |
| record | ^6.2.0 | WAV audio recording (16kHz mono for LiteRT-LM) |
| image_picker | ^1.1.2 | Camera JPEG capture |
| video_compress | ^3.1.0 | Async MP4 compression |
| permission_handler | ^11.3.1 | Runtime permissions |
| smart_auth | ^3.2.0 | Android SMS Retriever API for OTP autofill |
| connectivity_plus | ^7.1.0 | Network state for WiFi check + offline sync |
| http | ^1.6.0 | REST calls to Medplum |
| url_launcher | ^6.3.0 | tel:112 emergency dialer |
| path_provider | ^2.1.5 | Temp/docs directory paths |
| google_fonts | ^6.2.1 | Lexend font system-wide (resolves to 6.3.3) |
| flutter_webrtc | ^1.3.0 | WebRTC P2P video (resolves to 1.4.1) |

### Android (Gradle) dependencies
| Artifact | Version | Role |
|---|---|---|
| com.google.android.fhir:engine | 1.2.0 | FHIR SDK, encrypted SQLite |
| com.google.ai.edge.litertlm:litertlm-android | 0.10.2 | On-device Gemma 4 inference |
| net.zetetic:sqlcipher-android | 4.6.1 | Encryption at rest |
| kotlinx-coroutines-android | 1.10.1 | Native bridge coroutines |

---

## Current App State

### WORKING (confirmed in code, CI green)

- **App launches and navigates** — session guard prevents medicalSessionProvider from hijacking auth flow (loginIdentity, loginVerification, modelDownload routes are protected)
- **CNP validation** — full official spec rewrite: S=1-9 (S=9 non-resident valid), county set includes 99 (foreign residents), month 01-12, day 01-31, checksum verified; `isAdult()` enforces 18+ with Romanian error message; test CNP `1850415150017` documented with full checksum trace in source
- **OTP system** — demo OTP = **last 6 digits** of CNP (`substring(7,13)`); for CNP 1850415150017 → OTP 150017; 3-attempt lockout; SmartAuth SMS listener wired; **button stays disabled until all 6 boxes filled** (`setState` fix applied to `_onDigitChanged` and `_startSmsListener`)
- **Home screen** — Stitch-design rewrite: inline header "Bună ziua, Maria!" + "Cum vă simțiți astăzi?", 4 triage cards (Voice, Photo, Text, Emergency 112), glassmorphism bottom nav (BackdropFilter blur:20)
- **Bottom nav labels** — "Acasă", "Dosar Medical" (was "Istoric"), "Medic" (was "Doctorul Meu")
- **AI status indicator** — pill below header subtitle: yellow "AI se încarcă..." → green "AI pregătit" when `initializeModel()` succeeds; calls `_checkAiStatus()` in `initState()`
- **Legal screens** — `LegalDocumentModal` rewritten from Stitch; `LegalDocumentType` enum (terms/privacy); full Romanian GDPR content; glassmorphism back button; all `#0D631B` green replaced with `#5BA4CF`; backward-compat with existing string callers
- **History screen** — title changed from "Istoric Medical" to "Dosar Medical"
- **LiteRT-LM E2B integration** — real Engine via `litertlm-android:0.10.2`; Romanian system prompt; dual-path model lookup (`filesDir/models/` or `/sdcard/Download/`); sideloaded model auto-copied to app-private storage
- **Audio recording** — WAV 16kHz mono for LiteRT-LM; async WAV→AAC via `AudioTranscodeChannel` (Android MediaCodec, no FFmpeg)
- **Camera capture** — JPEG quality 85 for inference; async MP4 compression for storage
- **Model download screen** — WiFi check every 5s, DownloadManager progress polling every 2s, error reason codes (ERROR_HTTP_DATA_ERROR etc.), auto-navigate after download
- **Model download URL** — `http://192.168.0.37:8080/gemma-4-E2B-it.litertlm` (local GX10, testing only); `usesCleartextTraffic="true"` enabled
- **VideoConsultationScreen** — RTCVideoView, PiP local camera, mute toggle, voice visualizer, chat strip, end-call navigation
- **Emergency routing** — SessionState.emergency → EmergencyScreen → tel:112
- **FHIR local storage** — SQLCipher encrypted SQLite; mock data seeded on first launch
- **Lexend font** — `GoogleFonts.lexendTextTheme()` system-wide; DESIGN.md committed

### BROKEN / NOT YET TESTED ON DEVICE

- **Login screen visibility** — scroll fix applied (removed SizedBox.expand, crossAxisAlignment.stretch, phantom bottomNavigationBar removed), CI builds passing, **NOT YET CONFIRMED ON DEVICE**
- **LiteRT-LM actual inference** — model at `/sdcard/Download/gemma-4-E2B-it.litertlm` on test device (Pixel 9 Pro); `initializeModel()` wired; **AI status indicator on home screen will show green if init succeeds — not yet observed on device**
- **Model download in production** — URL is `http://192.168.0.37:8080` (local GX10 only); production endpoint not implemented
- **WebRTC signaling** — PeerConnection wired with Google STUN; no signaling server; remote video stays black
- **Document sharing** — chat strip UI present; `_onAttachDocument` and `_onSendMessage` are empty stubs
- **Text card inference** — `'runInference'` MethodChannel method not yet implemented in `LiteRtLmChannel.kt`; currently falls back to SnackBar "Mesaj primit"
- **Login camera extraction** — `_extractViaCamera()` passes `File('dummy_id.jpg')`; not real OCR
- **Medplum auth** — fictional `client_id`; will 401; skipped for hackathon
- **Firebase/FCM** — no `google-services.json`; FCM returns stub token; skipped for hackathon
- **DeviceConflictModal** — implemented but never triggered from auth flow
- **Language toggle** — RO/EN buttons exist with `onTap: () {}`; non-functional

---

## Key Files

### Dart / Flutter
| File | Role |
|---|---|
| lib/main.dart | Entry point; FHIR init; model file check; routes to modelDownload or loginIdentity |
| lib/core/providers/app_navigation_provider.dart | AppRoute enum + session guard (auth routes protected) + needsModelDownload flag |
| lib/core/providers/medical_session_provider.dart | SessionState machine; calls AI engine; writes FHIR |
| lib/core/services/ai_engine_service.dart | LiteRT-LM bridge; dual-path model lookup; Romanian fallback; `isInitialized` static flag |
| lib/core/services/cnp_service.dart | Full official CNP spec; isValid (S=9, county 99, 18+); extractDemoOtp last-6-digits; isAdult |
| lib/core/services/audio_recording_service.dart | WAV recording + fire-and-forget AAC transcode |
| lib/core/services/camera_service.dart | JPEG capture + async MP4 compression |
| lib/ui/screens/model_download_screen.dart | First-launch model download; WiFi check; progress polling; error reason codes |
| lib/ui/screens/login_identity_screen.dart | CNP + phone login; 18+ age validation; real-time CNP validation |
| lib/ui/screens/login_verification_screen.dart | 6-digit OTP; setState fix (button enables correctly); SmartAuth; legal modals |
| lib/ui/screens/home_screen.dart | 4-card Stitch design; AI status indicator; glassmorphism nav; all triage logic |
| lib/ui/screens/history_screen.dart | "Dosar Medical" (was "Istoric Medical"); FHIR list |
| lib/ui/screens/my_doctor_screen.dart | Doctor profile; mock incoming call |
| lib/ui/screens/waiting_room_screen.dart | Consent before video call |
| lib/ui/screens/video_consultation_screen.dart | RTCVideoView; PiP; mute; voice visualizer; chat strip |
| lib/ui/theme/theme.dart | AppTheme + GoogleFonts.lexendTextTheme + AccessibleTouchTarget |
| lib/ui/widgets/legal_document_modal.dart | Stitch-based legal screens; LegalDocumentType enum; GDPR content |
| DESIGN.md | The Dignified Guardian design system (permanent reference) |

### Kotlin / Android
| File | Role |
|---|---|
| android/.../MainActivity.kt | Registers 5 MethodChannels |
| android/.../channels/LiteRtLmChannel.kt | Gemma 4 E2B inference; getModelPath dual-path check |
| android/.../channels/FhirEngineChannel.kt | Google FHIR SDK CRUD + mock data seed |
| android/.../channels/AudioTranscodeChannel.kt | MediaCodec WAV→AAC (no FFmpeg) |
| android/.../channels/TelemedicineChannel.kt | FCM stub + WebRTC answerCall stub |
| android/.../services/ModelDownloadService.kt | DownloadManager; startDownload; getDownloadProgress + reason codes |
| android/.../app/build.gradle.kts | compileSdk=36; litertlm 0.10.2; FHIR SDK; SQLCipher |
| android/.../AndroidManifest.xml | All permissions; usesCleartextTraffic; READ_EXTERNAL_STORAGE ≤32 |

---

## Device Info

| Item | Value |
|---|---|
| Test device | Google Pixel 9 Pro (serial: 4C041FDAP006Z1) |
| Model file location | /sdcard/Download/gemma-4-E2B-it.litertlm |
| ADB | USB cable (unreliable); wireless not configured |
| Install method | Download APK from GitHub Actions artifact on phone browser |
| GX10 model server | http://192.168.0.37:8080 (local dev only) |

---

## Priority Tasks

### P0 — DONE
- [x] LiteRT-LM pinned to 0.10.2, model path unified, initializeModel wired
- [x] Session guard — auth routes protected from AI state hijacking
- [x] CNP validation rewritten to official spec (S=9, county 99, 18+ age)
- [x] OTP: last-6-digits formula, button state fixed (setState in onDigitChanged)
- [x] Login screen scroll/visibility fix committed

### P1 — IN PROGRESS
- [ ] **Confirm login screen visible on device** (CI passing, untested on device)
- [ ] **Confirm AI status indicator shows green on device** (model on sdcard, initializeModel not yet observed succeeding)

### P1 — NEXT
- [ ] Wire `'runInference'` in `LiteRtLmChannel.kt` for text card
- [ ] WebRTC signaling server on GX10 for real doctor↔patient video

### P2 — NEXT
- [ ] Production model download endpoint (replace 192.168.0.37:8080)
- [ ] Real camera OCR in login (replace dummy_id.jpg)
- [ ] Make GitHub repo public before May 18 deadline
- [ ] Record competition demo video

### P3 — NEXT
- [ ] DeviceConflictModal trigger from auth flow
- [ ] Language toggle (RO/EN)
- [ ] History item detail screen

---

## Hackathon

- **Deadline:** May 18, 2026 — **23 days remaining**
- **Public repo required:** currently PRIVATE — **must make public before deadline**
- **Demo video:** not yet recorded
- **Gemma 4 on-device status:** model file present on test device; `initializeModel()` wired; end-to-end inference **not yet confirmed**

## Patient Demo Story (for competition video)
Maria, 72, Brănești, chest pain, no car, hospital 40km away.
Opens TeleMed_K → voice/photo/text triage → Gemma 4 analyzes on-device →
urgency detected → one tap calls 112 OR books teleconsultation with Dr. Bogheanu.
NGO provides the device itself for patients who cannot afford one.
