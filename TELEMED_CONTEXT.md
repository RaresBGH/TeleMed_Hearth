# TeleMed_K — Project Context for AI Assistant
Last updated: 2026-05-02

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
| table_calendar | ^3.1.0 (resolves 3.2.0) | Month calendar widget for Programări |

### Android (Gradle) dependencies
| Artifact | Version | Role |
|---|---|---|
| com.google.android.fhir:engine | 1.2.0 | FHIR SDK, encrypted SQLite |
| com.google.ai.edge.litertlm:litertlm-android | 0.10.2 | On-device Gemma 4 inference |
| net.zetetic:sqlcipher-android | 4.6.1 | Encryption at rest |
| kotlinx-coroutines-android | 1.10.1 | Native bridge coroutines |

---

## Current App State

### VERIFIED ON DEVICE

- **Auth — CNP + OTP** — CNP validation: full official spec (S=1-9, S=9 valid, county 99, 18+, checksum); demo OTP = last 6 digits of CNP (`substring(7,13)`); 3-attempt lockout; SmartAuth SMS listener; button disabled until all 6 boxes filled
- **Phone validation** — `07XXXXXXXX` format enforced in real-time on identity screen
- **Model download — sovereign server** — `ModelDownloadForegroundService.kt` downloads from `https://telemed-b.duckdns.org/gemma-4-E2B-it.litertlm` (Caddy 2.11.2 on GX10, Let's Encrypt TLS via DuckDNS DNS-01)
- **Model download — OkHttp + foreground service + resume** — OkHttp replaces DownloadManager; HTTP Range header resume; model written to `filesDir/models/`; foreground service survives backgrounding; triggers only after auth completes; mobile data allowed with soft warning
- **Model download auto-advance** — STATUS_SUCCESS → `unawaited(initializeModel())`; `Future.delayed(1500ms)` then `navigateTo(AppRoute.home)`; button hidden permanently on success; terminal state guard in `_startDownload()`
- **Chat screen with Gemma 4** — full Romanian dialog UI; raw JSON stripped from AI output before rendering; follow-up text inference correct on all subsequent turns
- **Patient chat bubbles** — patient messages styled distinctly from AI response bubbles (brand-blue background vs light-blue AI)
- **Single FHIR entry per consultation** — "Finalizează Dialogul" writes exactly one Observation per session; no-duplicate constraint enforced; mock seed data removed
- **Dosar Medical detail tap** — tapping a history entry opens bottom sheet with full conversation replay and initial AI response; badge shows "Dialog Salvat" vs "Triaj AI"
- **Resume from history** — "Continuă conversația" button parses saved note into `List<ChatMessage>` (strips `[AI/Pacient] HH:mm:` prefix), calls `prepareResume()`, navigates to `MedicalResponseScreen` with `initialMessages` pre-populated
- **Back button exit dialog** — `AlertDialog` with "Finalizează Dialogul" (saves + exits) and "Ieși fără a salva" (discards); `PopScope(canPop: false)` routes hardware back through same `_onBack()` handler; dismissing stays in chat
- **Emergency 112 routing** — `SessionState.emergency` → `EmergencyScreen` → `tel:112` dialer
- **App navigation session guard** — auth + download routes protected from session-state hijacking
- **LiteRT-LM E2B integration** — real Engine via `litertlm-android:0.10.2`; dual-path model lookup (`filesDir/models/` or `/sdcard/Download/`)
- **AI acknowledgment structure** — system prompt enforces a/b/c: Confirmare / Evaluare / Continuare; applies to voice, text, photo
- **Photo loading indicator** — "Se analizează fotografia..." replaces animated dots while `evaluateMedia()` runs; `_isPhotoAnalyzing` bool tracks photo-specific processing
- **Audio recording** — WAV 16kHz mono; async WAV→AAC transcode (MediaCodec, no FFmpeg)
- **Camera capture** — JPEG quality 85 for inference; async MP4 compression for storage
- **VideoConsultationScreen** — RTCVideoView, PiP, mute, voice visualizer, chat strip (signaling absent — remote stays black)
- **Legal screens** — GDPR-compliant Romanian content; `LegalDocumentType` enum; accessible touch targets
- **Lexend font** — `GoogleFonts.lexendTextTheme()` system-wide
- **Dark theme** — `AppTheme.darkTheme` defined; `MaterialApp(themeMode: ThemeMode.system)` follows device setting automatically; no manual toggle needed

### BUILT — AWAITING DEVICE TEST

- **Mock patient DB (5 patients)** — `FhirEngineChannel.kt` seeds 5 realistic Romanian patients (Maria Ionescu CNP 2540203152485, Ion Popescu CNP 1490815054321, Elena Dumitrescu, Gheorghe Stan, Ana Constantin) each with CNP identifier, name, DOB, phone, and one clinical Condition (Hipertensiune / Diabet tip 2 / Artrită / Insuficiență cardiacă / BPOC)
- **Returning vs new user detection** — `PatientAuthNotifier.loadPatient(cnp)` searches FHIR by `urn:oid:1.2.40.0.10.1.4.3.1` identifier; returning user → first name extracted, `isReturningUser=true`, navigates to home/download; new user → navigates to `AppRoute.profileCompletion`
- **Profile completion screen** — new users enter first name, last name, phone; creates FHIR Patient resource via `handleSavePatient`; sets `patientFirstName`; navigates to home or model download based on model presence
- **Dynamic patient name greeting** — home screen reads `patientAuthProvider.patientFirstName`; shows "Bună ziua, [Prenume]!" or "Bună ziua!" if name not loaded; reactive to `patientAuthProvider` via `ref.watch`
- **Full RO/EN language switch** — `AppStrings` class with ~120 keys across all 12 screens in `lib/core/l10n/app_strings.dart`; `AppStrings.of(lang, 'key')` in every `build()` method; `ref.watch(languageProvider)` makes all visible text reactive immediately; RO/EN toggle in AppBar of home, history, and doctor screens
- **Shared bottom nav widget** — `AppBottomNavBar` (ConsumerWidget, glassmorphism BackdropFilter blur:20); labels always "Acasă" / "Dosar Medical" / "Medic"; icons `home` / `folder_shared` / `medical_services`; replaces custom `BottomNavigationBar` in all three tab screens; active tab highlighted in `#5BA4CF`
- **Session context isolation logging** — `Log.d("New conversation created — [handler] session isolated")` at start of engine-ready branch in `evaluateAudio`, `evaluateMedia`, `handleRunInference`; each call to `runEngineInference` creates a fresh `Conversation` via `.use { }` (Kotlin `AutoCloseable` guarantees `close()`)
- **Romanian prompt quality** — `buildSystemPrompt()` RO branch rewritten: everyday vocabulary ("vorbești simplu, ca un vecin de încredere"), ≤15 words per sentence, "dumneavoastră" once then "dvs.", 5 few-shot examples (headache / chest pain with emergency=true / dizziness / fatigue / skin rash photo)
- **Photo timeout 30s** — `evaluateMedia()` image path wrapped in `withTimeout(30_000L)`; `TimeoutCancellationException` caught separately from outer catch; fallback: "Nu am putut analiza fotografia. Vă rugăm descrieți simptomele prin voce sau text."
- **Microphone release** — `AudioRecordingService.stopAndRelease()` called from `MedicalSessionNotifier.reset()`, `_onFinalize()` before FHIR write, and `dispose()` in `MedicalResponseScreen` (via `unawaited`)
- **Finalize during inference deadlock fix** — `_onFinalize()` checks `_isProcessing`; sets `_cancelRequested=true`; polls 100ms intervals up to 3s for inference to complete; inference handlers check `_cancelRequested` after await and abort; force-finalizes with current `_messages` on timeout; never leaves app stuck
- **Duplicate FHIR entry fix on resume** — `prepareResume()` accepts `existingObservationId`; `finalizeConsultation()` calls `_fhirRepository.updateObservation(id, payload)` instead of `saveObservation` when ID present; `FhirEngineChannel.kt` `handleUpdateObservation` calls `fhirEngine!!.update(observation)`
- **Dashboard screen** — new post-auth landing screen; loads primary FHIR Condition, last dialog date, active medication, 2 recent Observations; CTA navigates to triaj; `AppRoute.dashboard` is initial post-auth route
- **LanguageToggle shared widget** — pill toggle (88×36dp, 6dp radius, #5BA4CF border); replaces all three per-screen implementations in home, history, doctor AppBars; calls `languageProvider` + `aiEngineServiceProvider`
- **DateFormatter utility** — `lib/core/utils/date_formatter.dart`; `format(iso, {includeTime})` replaces `_formatDate` in dashboard and `_formatDateTime` in history; single source of truth
- **DialogDetailSheet shared widget** — `lib/ui/widgets/dialog_detail_sheet.dart`; static `show()` method replaces duplicated ~130-line bottom sheet in history and dashboard; handles replay, "Continuă conversația", status badge
- **aiReadyProvider** — `FutureProvider<bool>` in `lib/core/providers/ai_ready_provider.dart`; shared between home and dashboard screens; eliminates redundant `AiEngineService(FhirRepository()).initializeModel()` calls in both `initState()` methods
- **PatientProfileScreen (Profil Pacient)** — FHIR Patient read (CNP + name read-only, phone + email editable); photo picker (image_picker, 200×200 compressed to FHIR Patient.photo); account deletion wipes FHIR DB (Patient + Observations + Conditions + Encounters + Appointments) + model file; phone-change blocked with dialog (B0 pending); email saves to FHIR Patient.telecom; accessible from Dashboard avatar tap
- **DoctorProfileScreen (reusable template)** — parametrized widget (showBackButton, showSpecialtyPicker, doctorName, practitionerRef); family doctor variant wraps MyDoctorScreen; specialist variant used by SpecialistsScreen; "Trimite mesaj" → MedicalResponseScreen with AI-preseeded prompt ("Bună ziua, am o întrebare pentru Dr. [name]."); "Programare" → AppointmentsScreen; FHIR info rows (last consult, active prescription)
- **AppointmentsScreen (Programări)** — table_calendar 3.2.0, ro_RO locale; FHIR Appointment CRUD (saveAppointment / getAppointments scoped by Patient CNP); inline booking panel (hardcoded slots MVP); appointment cards with status chips (Confirmată/Finalizată/Anulată); "Intră în consultație" → WaitingRoomScreen with appointmentId; "Solicită programare nouă" → inline panel; Practitioner scoping (MVP: "family" ref, TODO for real Practitioner ID)
- **SpecialistsScreen (Specialiști)** — 8 specialties (Cardiologie, Neurologie, Dermatologie, Ortopedie, Oftalmologie, Pediatrie, Psihiatrie, Ginecologie); diacritic-insensitive search filter; 2-column grid; taps → DoctorProfileScreen(specialist variant); Dr. Adriana Bogheanu hardcoded for Pediatrie; other specialties use placeholder name pending Medplum Practitioner data
- **WaitingRoomScreen (compound — A5)** — replaces stub; two-state AnimatedSwitcher (consent → buffer); STATE A: consent card, "Sunt de acord" → STATE B; STATE B: video preview (local only, no signaling), mic/video toggle, private-space checkbox, "Intră în apel" → VideoConsultationScreen; "Anulează" exits; doctorName param replaces hardcoded name; appointmentId param wired from AppointmentsScreen

### PENDING IMPLEMENTATION

- **Async messaging thread (Trimite mesaj flow)** — patient ↔ doctor text thread initiated from Medic tab; threaded UI with timestamps; push notification delivery via FCM when online
- **AI assistant as persistent channel monitor** — Gemma 4 monitors all voice/text/photo triage, messaging, and consultation history; routes urgent cases toward 112; surfaces clinical insights across sessions
- **Phone number change + device transfer flow (B0)** — new device account creation route; transfers all FHIR data to new device on phone number change; requires new Stitch screens; blocked in PatientProfileScreen with "Funcție în curând disponibilă" dialog

### STILL BROKEN / SKIPPED FOR HACKATHON

- **LiteRT-LM actual on-device inference** — model in `filesDir/models/`; `initializeModel()` wired; AI status indicator will show green if init succeeds — **not yet observed on device**
- **Login screen on-device visibility** — scroll fix committed, CI green — **not confirmed on device**
- **WebRTC signaling** — PeerConnection wired with Google STUN; no signaling server deployed; remote video stays black
- **Text card → inference** — `handleRunInference` implemented in Kotlin; end-to-end path from text card UI → MethodChannel → model output not yet device-tested
- **Document sharing** — `_onAttachDocument` and `_onSendMessage` are empty stubs
- **Login camera OCR** — `_extractViaCamera()` passes `File('dummy_id.jpg')`; not real OCR
- **Medplum auth** — fictional `client_id`; will 401; skipped for hackathon
- **Firebase/FCM** — no `google-services.json`; FCM returns stub token; skipped for hackathon
- **DeviceConflictModal** — implemented but never triggered from auth flow

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
| lib/ui/screens/dashboard_screen.dart | Post-auth landing; health summary, quick status, recent activity; CTA → triaj |
| lib/ui/screens/home_screen.dart | 4-card Stitch design; AI status indicator; glassmorphism nav; all triage logic |
| lib/ui/screens/history_screen.dart | "Dosar Medical" (was "Istoric Medical"); FHIR list |
| lib/ui/screens/my_doctor_screen.dart | Doctor profile; mock incoming call |
| lib/ui/screens/waiting_room_screen.dart | Consent before video call |
| lib/ui/screens/video_consultation_screen.dart | RTCVideoView; PiP; mute; voice visualizer; chat strip |
| lib/ui/theme/theme.dart | AppTheme + GoogleFonts.lexendTextTheme + AccessibleTouchTarget |
| lib/ui/widgets/language_toggle.dart | Shared RO/EN pill toggle (88×36dp); used in home, history, doctor AppBars |
| lib/ui/widgets/dialog_detail_sheet.dart | Shared FHIR Observation bottom sheet; used by history and dashboard |
| lib/core/utils/date_formatter.dart | `DateFormatter.format(iso, {includeTime})`; replaces per-screen date helpers |
| lib/core/providers/ai_ready_provider.dart | `FutureProvider<bool>` shared by home and dashboard; calls `initializeModel()` once |
| lib/ui/widgets/legal_document_modal.dart | Stitch-based legal screens; LegalDocumentType enum; GDPR content |
| lib/ui/screens/patient_profile_screen.dart | FHIR Patient read/write; photo picker; account deletion |
| lib/ui/screens/doctor_profile_screen.dart | Reusable parametrized doctor profile; family + specialist variants |
| lib/ui/screens/appointments_screen.dart | table_calendar; FHIR Appointment CRUD; inline booking |
| lib/ui/screens/specialists_screen.dart | 8 specialties; diacritic search; routes to DoctorProfileScreen |
| lib/core/models/specialty.dart | Specialty data model (appStringKey, icon, practitionerRef) |
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

## Infrastructure

| Item | Value |
|---|---|
| GX10 LAN IP (WiFi) | 192.168.0.101 |
| GX10 LAN IP (Ethernet) | 192.168.0.144 — interface `enP7s7`; no `tc` rate limiting applied |
| Caddy version | 2.11.2 (ARM64 binary) |
| Caddy systemd service | `caddy-telemed` — running on GX10, managed by systemd |
| Public HTTPS endpoint | `https://telemed-b.duckdns.org` — serves `gemma-4-E2B-it.litertlm` |
| TLS certificate | Let's Encrypt, issued via DuckDNS DNS-01 challenge; auto-renews |
| Router port forward | TCP 443 → 192.168.0.101:443 on TP-Link AX5400 |
| Old local endpoint | `http://192.168.0.37:8080` — still referenced in app source; superseded by HTTPS above |
| Required app change | Update model URL in `model_download_screen.dart` to `https://telemed-b.duckdns.org/gemma-4-E2B-it.litertlm`; `usesCleartextTraffic` can remain for local dev fallback |

---

## Key Architecture Decisions

- Model downloads post-auth to `filesDir` via OkHttp foreground service; all inference isolated per session (fresh Conversation per call)
- Single FHIR Observation per dialog, saved only on explicit "Finalizează Dialogul"; CNP-filtered history so each patient sees only their own records
- Language switching via AppStrings (~130 keys, reactive, no restart); `LanguageToggle` pill widget shared across all tab AppBars
- **Video call initiated ONLY from a confirmed appointment on Programări screen** — NOT from Medic tab directly; Medic tab routes to Programări for scheduling
- **AI assistant monitors all communication channels** (voice triage, messaging, consultation history) and routes urgent cases toward 112 emergency call
- **Profil Pacient accessible from Dashboard screen** via profile avatar; editable fields update FHIR Patient resource in local encrypted DB
- AppRoute enum has **15 values**. Added in A1–A5: `AppRoute.specialists` → SpecialistsScreen; `AppRoute.appointments` → AppointmentsScreen; `AppRoute.patientProfile` → PatientProfileScreen
- **DoctorProfileScreen is a reusable parametrized template** — used by MyDoctorScreen (family doctor tab) and SpecialistsScreen (specialist sub-screens). Parameters: showBackButton, showSpecialtyPicker, doctorName, practitionerRef.
- **"Trimite mesaj" routes to MedicalResponseScreen with AI preseed** — interim until Medplum async messaging is implemented. Preseed: "Bună ziua, am o întrebare pentru Dr. [name]."
- **Per-doctor appointment scoping** — FHIR Appointment stores practitionerRef per resource. Patient sees all their appointments; each doctor (Medplum) sees only their own. MVP uses "family" as default practitionerRef.
- **WaitingRoomScreen is compound** — consent state + buffer state in one screen, switched by AnimatedSwitcher. Entry: AppointmentsScreen "Intră în consultație". Exit chain: → VideoConsultationScreen.
- **Phone change blocked pending B0** — PatientProfileScreen allows typing a new phone number but blocks save with a dialog. Full device-transfer flow requires new Stitch screens and is tracked as B0.

---

## Code Quality

Two full audit cycles completed 2026-05-02. Codebase is clean: **0 critical, 0 high, 0 medium, 0 low** issues remaining.

Refactoring completed during audit:
- Dead code removed — 3 dead service files, 2 dead screens/routes, 1 unused Gradle dependency
- Duplicate logic unified — `AiEngineService.isModelOnDisk()`, `DateFormatter`, `DialogDetailSheet`, `_buildHistoryContext()`, `aiReadyProvider`
- AppStrings coverage complete — all screens fully wired; 3 new keys added (`chat.followup_prompt`, `doctor.unknown_date`, `doctor.name`)
- State management — `MedicalSessionState` immutable value object; data-shuttle fields removed from notifier
- Error handling — `finalizeConsultation()` wrapped in try/catch; `reset()` awaits `stopAndRelease()`

---

## Priority Tasks

### P0 — ACTIVE
- [ ] **Device test all BUILT — AWAITING DEVICE TEST items** — install latest APK on Pixel 9 Pro and verify each item in the "BUILT — AWAITING DEVICE TEST" section above; update to VERIFIED ON DEVICE as each passes

### P0 — DONE
- [x] LiteRT-LM pinned to 0.10.2, model path unified, initializeModel wired
- [x] Session guard — auth routes protected from AI state hijacking
- [x] CNP validation rewritten to official spec (S=9, county 99, 18+ age)
- [x] OTP: last-6-digits formula, button state fixed
- [x] Login screen scroll/visibility fix committed
- [x] Model download: OkHttp + foreground service + resume + triggers after auth
- [x] Production model download URL — `https://telemed-b.duckdns.org/gemma-4-E2B-it.litertlm`
- [x] Model download auto-advances to home on STATUS_SUCCESS (1.5s delay, unawaited initializeModel)
- [x] Model download terminal state guard — success blocks re-entry
- [x] Chat screen: Gemma 4 dialog, patient bubbles, raw JSON stripped, follow-up inference fixed
- [x] FHIR: single entry per consultation, no duplicates, mock data removed
- [x] AI response acknowledgment structure (a/b/c: confirm/evaluate/continue)
- [x] Photo loading indicator "Se analizează fotografia..." during photo processing
- [x] Resume conversation from Dosar Medical — "Continuă conversația" + prepareResume + initialMessages
- [x] Back button exit dialog — Finalizează/Ieși fără a salva; hardware back via PopScope
- [x] Mock patient DB — 5 realistic Romanian patients seeded in FHIR on first launch
- [x] Returning vs new user detection — PatientAuthNotifier.loadPatient by CNP identifier
- [x] Profile completion screen for new users
- [x] Dynamic patient name greeting on home screen
- [x] Full RO/EN language switch — AppStrings ~120 keys, all 12 screens reactive
- [x] Shared bottom nav widget — AppBottomNavBar glassmorphism, labels Acasă/Dosar Medical/Medic
- [x] Session context isolation — new Conversation per triage call, Log.d in each handler
- [x] Romanian prompt quality — simple vocabulary, ≤15 words/sentence, 5 few-shot examples
- [x] Photo timeout 30s with Romanian fallback in evaluateMedia
- [x] Microphone release on session reset, finalize, and screen dispose
- [x] Finalize during inference deadlock fix — 3s timeout, force-finalize
- [x] Duplicate FHIR entry fix on resume — updateObservation when existingObservationId present
- [x] Dark theme — AppTheme.darkTheme; ThemeMode.system; no manual toggle
- [x] Dashboard screen — post-auth landing; AppRoute.dashboard initial route; live FHIR data
- [x] LanguageToggle shared widget — replaces all per-screen RO/EN implementations
- [x] Two full audit cycles — codebase clean: 0 critical, 0 high, 0 medium, 0 low
- [x] PatientProfileScreen (A1) — FHIR Patient r/w, photo picker, account deletion, B0 phone-change guard
- [x] DoctorProfileScreen (A2) — reusable template; Trimite mesaj preseed; Programare → appointments
- [x] AppointmentsScreen (A3) — table_calendar 3.2.0; FHIR Appointment CRUD; inline booking panel
- [x] SpecialistsScreen (A4) — 8 specialties; diacritic search; → DoctorProfileScreen specialist variant
- [x] WaitingRoomScreen (A5) — compound consent+buffer; AnimatedSwitcher; → VideoConsultationScreen chain
- [x] All lib/ warnings + test/ errors resolved — 0 errors, 0 warnings, commit 4fbea03

### P1 — NEXT
- [ ] **Make GitHub repo public before May 18 deadline** — currently PRIVATE; required for hackathon submission
- [ ] **Record competition demo video** — patient story: Maria, 72, chest pain, no car → voice triage → 112 or teleconsult
- [ ] **Device test all A1–A5 screens** — install latest APK (commit 4fbea03) on Pixel 9 Pro; verify PatientProfile, DoctorProfile, Appointments, Specialists, WaitingRoom (compound)
- [ ] End-to-end text card inference device test (handleRunInference → model output)
- [ ] WebRTC signaling server on GX10 for real doctor↔patient video

### P2 — NEXT
- [ ] Real camera OCR in login (replace `File('dummy_id.jpg')` in `_extractViaCamera()`)
- [ ] Phone change + device transfer flow (B0) — requires new Stitch screens before implementation

### P3 — NEXT
- [ ] DeviceConflictModal trigger from auth flow

---

## Hackathon

- **Deadline:** May 18, 2026 — **16 days remaining**
- **Public repo required:** currently PRIVATE — **must make public before deadline**
- **Demo video:** not yet recorded
- **Gemma 4 on-device status:** model file present on test device; `initializeModel()` wired; end-to-end inference **not yet confirmed**
- **Latest commit:** 4fbea03 — A1–A5 screens complete, 0 errors, 0 warnings

## Patient Demo Story (for competition video)
Maria, 72, Brănești, chest pain, no car, hospital 40km away.
Opens TeleMed_K → voice/photo/text triage → Gemma 4 analyzes on-device →
urgency detected → one tap calls 112 OR books teleconsultation with Dr. Bogheanu.
NGO provides the device itself for patients who cannot afford one.
