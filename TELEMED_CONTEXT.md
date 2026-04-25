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

- **App launches and navigates** — routing fixed; session guard prevents medicalSessionProvider from hijacking auth flow
- **CNP validation** — real checksum algorithm, 48 valid county codes, green/red border feedback
- **Smart OTP bypass** — demo OTP = last 6 digits of CNP; 3-attempt lockout; SmartAuth SMS listener wired
- **LiteRT-LM E2B integration** — real Engine via `com.google.ai.edge.litertlm:litertlm-android:0.10.2`; Romanian system prompt hardcoded in `LiteRtLmChannel.kt`; correct `message.toString()` streaming API; `getModelPath` channel returns first existing path of: `filesDir/models/gemma-4-E2B-it.litertlm` or `/sdcard/Download/gemma-4-E2B-it.litertlm`; sideloaded model is copied to app-private storage automatically
- **Audio recording** — WAV 16kHz mono for LiteRT-LM inference; async WAV→AAC transcode via `AudioTranscodeChannel` (Android MediaCodec, no FFmpeg)
- **Camera capture** — JPEG quality 85 for inference; async MP4/LowQuality compression for Medplum storage; FileProvider configured for temp files
- **Model download screen** — WiFi check every 5s, DownloadManager progress polling every 2s, auto-navigates to login after completion; error reason codes mapped from DownloadManager (ERROR_HTTP_DATA_ERROR etc.)
- **Model download URL** — currently `http://192.168.0.37:8080/gemma-4-E2B-it.litertlm` (local GX10 server for testing); `android:usesCleartextTraffic="true"` enabled; READ_EXTERNAL_STORAGE permission added (maxSdkVersion=32)
- **VideoConsultationScreen** — RTCVideoView for remote + PiP local camera, mic mute toggle, 5-bar animated voice visualizer, chat strip, end-call navigation to home; built from Stitch design
- **Emergency routing** — SessionState.emergency → EmergencyScreen → tel:112 (url_launcher)
- **FHIR local storage** — Google Android FHIR SDK, SQLCipher encrypted SQLite; mock data seeded on first launch (Patient, Practitioner, Observation, Condition, MedicationRequest, Encounter)
- **Lexend font** — GoogleFonts.lexendTextTheme() applied system-wide; DESIGN.md committed as permanent design system reference
- **Session guard** — medicalSessionProvider state changes ignored while on loginIdentity, loginVerification, or modelDownload routes
- **Login screen** — phantom bottomNavigationBar removed; Ajutor button moved into body Column; CNP form, phone field, info prompt, CONTINUĂ button all present

### BROKEN / NOT YET TESTED ON DEVICE

- **Login screen visibility** — fix committed (removed SizedBox.expand, crossAxisAlignment.stretch), CI running, **NOT YET TESTED ON DEVICE**
- **LiteRT-LM actual inference** — model file at `/sdcard/Download/gemma-4-E2B-it.litertlm` on test device; `initializeModel()` wired in `main.dart`; **inference not yet confirmed working end-to-end**
- **Model download in production** — download URL is `http://192.168.0.37:8080` (local GX10, testing only); production endpoint not yet implemented
- **WebRTC signaling** — PeerConnection wired with Google STUN; no signaling server yet; remote video shows "Se conectează..." black placeholder permanently
- **Document sharing** — chat strip UI present (attach, placeholder text, send icons); `_onAttachDocument` and `_onSendMessage` are empty stubs
- **Medplum auth** — `client_id: 'telemed_k_mobile_client'` is fictional; OAuth2 token call will 401; skipped for hackathon
- **Firebase/FCM** — no `google-services.json`; `TelemedicineChannel.getFcmToken()` returns a stub string; skipped for hackathon
- **Login camera extraction** — `_extractViaCamera()` still passes `File('dummy_id.jpg')` to AI engine; not real camera OCR
- **DeviceConflictModal** — widget exists, logic implemented, but never triggered from auth flow
- **Language toggle** — RO/EN buttons appear in AppBar throughout; all have `onTap: () {}`; no localization framework
- **History item tap** — tapping a history record fires `onTap: () {}`; no detail screen

---

## Key Files

### Dart / Flutter
| File | Role |
|---|---|
| lib/main.dart | Entry point; FHIR init; model file check; routes to modelDownload or loginIdentity |
| lib/core/providers/app_navigation_provider.dart | AppRoute enum + session guard + needsModelDownload flag |
| lib/core/providers/medical_session_provider.dart | SessionState machine; calls AI engine; writes FHIR |
| lib/core/services/ai_engine_service.dart | LiteRT-LM Dart bridge; dual-path model lookup; Romanian fallback response |
| lib/core/services/cnp_service.dart | CNP validation + demo OTP extraction |
| lib/core/services/audio_recording_service.dart | WAV recording + fire-and-forget AAC transcode |
| lib/core/services/camera_service.dart | JPEG capture + async MP4 compression |
| lib/core/services/fhir_sync_service.dart | Offline→Medplum sync on connectivity restore |
| lib/core/services/telemedicine_service.dart | FCM token + WebRTC call signaling bridge |
| lib/data/repositories/fhir_repository.dart | Dart→FhirEngineChannel bridge |
| lib/ui/screens/model_download_screen.dart | First-launch model download UI |
| lib/ui/screens/login_identity_screen.dart | CNP + phone login; real-time CNP validation |
| lib/ui/screens/login_verification_screen.dart | 6-digit OTP; SmartAuth; legal modals |
| lib/ui/screens/home_screen.dart | Mic button → AI triage; camera button |
| lib/ui/screens/confirmation_screen.dart | Post-triage success; auto-home after 5s |
| lib/ui/screens/emergency_screen.dart | 112 dialer |
| lib/ui/screens/history_screen.dart | FHIR Observation/Condition list |
| lib/ui/screens/my_doctor_screen.dart | Doctor profile; mock incoming call |
| lib/ui/screens/waiting_room_screen.dart | Consent before video call |
| lib/ui/screens/video_consultation_screen.dart | RTCVideoView; PiP; mute; chat strip |
| lib/ui/theme/theme.dart | AppTheme + GoogleFonts.lexendTextTheme + AccessibleTouchTarget |
| DESIGN.md | The Dignified Guardian design system (permanent reference) |

### Kotlin / Android
| File | Role |
|---|---|
| android/.../MainActivity.kt | Registers 5 MethodChannels |
| android/.../channels/LiteRtLmChannel.kt | Gemma 4 E2B inference; getModelPath dual-path |
| android/.../channels/FhirEngineChannel.kt | Google FHIR SDK CRUD + mock data seed |
| android/.../channels/AudioTranscodeChannel.kt | MediaCodec WAV→AAC (no FFmpeg) |
| android/.../channels/TelemedicineChannel.kt | FCM stub + WebRTC answerCall stub |
| android/.../services/ModelDownloadService.kt | DownloadManager; startDownload; getDownloadProgress with reason codes |
| android/.../app/build.gradle.kts | compileSdk=36; litertlm 0.10.2; FHIR SDK; SQLCipher |
| android/.../AndroidManifest.xml | All permissions incl. READ_EXTERNAL_STORAGE ≤32; usesCleartextTraffic |

---

## Device Info

| Item | Value |
|---|---|
| Test device | Google Pixel 9 Pro (serial: 4C041FDAP006Z1) |
| Model file location | /sdcard/Download/gemma-4-E2B-it.litertlm |
| ADB | USB cable (unreliable connection); wireless not configured |
| Install method | Download APK from GitHub Actions artifact on phone browser |
| GX10 model server | http://192.168.0.37:8080 (local dev only) |

---

## Priority Tasks

### P0 — DONE
- [x] Pin litertlm-android to 0.10.2 (fixes fragile `latest.release`)
- [x] Unify model filename/path (was .gguf vs .litertlm mismatch)
- [x] Wire initializeModel() in main.dart (was never called)
- [x] Fix login screen routing (session guard added)
- [x] Remove phantom bottomNavigationBar from login screen

### P1 — IN PROGRESS
- [ ] **Confirm login screen visible on device** (CI running, untested)
- [ ] **Confirm AI inference works on device** (model on sdcard, end-to-end not tested)

### P1 — NEXT
- [ ] WebRTC signaling server on GX10 for real doctor↔patient video
- [ ] Real camera OCR in login (_extractViaCamera, currently uses dummy_id.jpg)

### P2 — NEXT
- [ ] Production model download endpoint (replace 192.168.0.37:8080)
- [ ] Document sharing via WebRTC data channel
- [ ] Make GitHub repo public before May 18 deadline

### P3 — NEXT
- [ ] DeviceConflictModal trigger from auth flow
- [ ] Language toggle (RO/EN) — add flutter_localizations
- [ ] History item detail screen

---

## Hackathon

- **Deadline:** May 18, 2026 — **23 days remaining**
- **Public repo required:** currently PRIVATE — **must make public before deadline**
- **Demo video:** not yet recorded
- **Competition requirement:** Gemma 4 on-device inference
  - Model file is on test device at /sdcard/Download/gemma-4-E2B-it.litertlm
  - Inference path is wired (AudioRecording → LiteRT-LM → FHIR → UI)
  - **End-to-end inference not yet confirmed on device**

## Patient Demo Story (for competition video)
Maria, 72, Brănești, chest pain, no car, hospital 40km away.
Opens TeleMed_K → voice input → Gemma 4 analyzes symptoms on-device →
urgency detected → one tap calls 112 OR books teleconsultation with Dr. Bogheanu.
NGO provides the device itself for patients who cannot afford one.
