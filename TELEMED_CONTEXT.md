# TeleMed_K — Project Context for AI Assistant
Last updated: 2026-05-05

## What This Is
Flutter telemedicine app for rural Romania. MVP for Dr. Bogheanu's clinic in Brănești, Dâmbovița.
Competition: Kaggle Gemma 4 Good Hackathon — deadline May 18, 2026 (12 days remaining).
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
| flutter_secure_storage | ^9.2.2 | OAuth token secure storage (M1) |
| url_launcher | ^6.3.0 | tel:112 emergency dialer |
| path_provider | ^2.1.5 | Temp/docs directory paths |
| google_fonts | ^6.2.1 | Lexend font system-wide (resolves to 6.3.3) |
| flutter_webrtc | ^1.3.0 | WebRTC P2P video (resolves to 1.4.1) |
| table_calendar | ^3.1.0 (resolves 3.2.0) | Month calendar widget for Programări |
| webview_flutter | ^4.10.0 | HTML legal document rendering (H4) |
| file_picker | ^8.1.2 | PDF + image + audio file selection (H9) |
| just_audio | ^0.9.42 | Inline voice replay in chat bubbles (H9) |

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
- **VideoConsultationScreen** — RTCVideoView, PiP, mute, voice visualizer; in-call DraggableScrollableSheet chat panel; WebRTC signaling server deployed on GX10 (H12); remote video works when both peers join same room
- **Legal screens** — GDPR-compliant Romanian content; `LegalDocumentType` enum; accessible touch targets
- **Lexend font** — `GoogleFonts.lexendTextTheme()` system-wide
- **Dark theme** — `AppTheme.darkTheme` defined; `MaterialApp(themeMode: ThemeMode.system)` follows device setting automatically; no manual toggle needed
- **H1 — Language toggle on login screen** — `LanguageToggle()` in login AppBar; switches correctly in both directions; all login strings reactive
- **H2 — Valid Romanian CNPs** — 5 checksum-valid CNPs (county 15, NNN 001–005) seeded; OTPs work correctly (last 6 digits); Medplum update script confirmed
- **Language toggle EN/RO** — confirmed on device build #64; defaults to EN; `setLanguage()` correctly updates both Dart and Kotlin layers; AI responds in selected language
- **Appointment screen** — past date selection blocked (`firstDay: DateTime.now()`); today shows only future slots; 30 slots available 09:00–23:30; booking confirmed syncs to Medplum with correct Patient reference (`Patient/{medplumId}`)
- **Doctor UI** — `https://telemed-doctor.duckdns.org` loads and authenticates via client_credentials; today's appointments listed using date range query (`date=ge...&date=lt...`); "Intră în consultație" joins WebRTC room
- **Medplum sync** — appointments, observations, and communications confirmed reaching Medplum FHIR R4; Medplum client ID `c18b54d9-f511-46db-903e-882b47dc3c63` is the correct active ClientApplication
- **WebRTC two-device video call** — confirmed end-to-end on build #64: patient Pixel 9 Pro + doctor Brave browser; signaling server `peer_joined` message triggers offer re-send when doctor joins after patient; TURN server at 34.185.191.34:3478 reachable
- **Waiting room mute/video** — buttons correctly disable/enable actual MediaStream tracks
- **Triage chat attachments** — voice bubble shows play/stop button with correct `attachmentPath`; photo bubble shows tappable thumbnail; both open full-screen on tap
- **AI conversation context** — conversation history passed as `customPrompt` to every `evaluateText`/`evaluateAudio`/`evaluateMedia` call; AI no longer repeats Turn 1 greeting
- **On-device AI inference** — Gemma 4 E2B confirmed responding on device; text inference working; voice inference working (returns response); `[name]` placeholder removed from system prompt
- **GitHub Actions secrets** — `MEDPLUM_CLIENT_ID` and `MEDPLUM_CLIENT_SECRET` confirmed set with correct values; build #60+ have working Medplum credentials
- **Doctor UI rewrite** — English interface confirmed loading at telemed-doctor.duckdns.org; doctor dropdown with 9 practitioners; appointment join window -21min to +30min; chat panel present; peer-left overlay present
- **Practitioner names** — all mock names confirmed in Medplum and Flutter constants; 9 real Medplum Practitioner UUIDs in practitioner_constants.dart
- **Dashboard doctor card** — label "Family Doctor:", taps to Medic tab; real name from `Practitioners.familyDoctorName`
- **Specialist screens** — all 8 specialties show real doctor names from Practitioners constants via `_doctorNameFor()`
- **My Profile** — save button shows success SnackBar (brand blue); back button primary blue; profile photo propagates to dashboard avatar via `patientAvatarProvider`
- **Triage chat** — first patient message + AI first response seeded as bubbles on `MedicalResponseScreen` entry (build #67)
- **Doctor message flow** — clean entry with no pre-populated bubble; AppBar shows doctor name; welcome card shows neutral message context
- **Dosar Medical** — audio and photo attachment paths serialized into FHIR note text; restored as playable/tappable bubbles on replay
- **Doctor UI join window** — widened to -60min / +120min from appointment start
- **Doctor UI sliding panel** — deployed and functional at telemed-doctor.duckdns.org; 3-state panel (Appointments / Patient Report / In-Call) confirmed loading
- **Doctor UI patient report** — Conditions and triage Observations load from Medplum; Mark reviewed PATCHes reviewed-by extension; Finalize PATCHes status:final
- **Dashboard doctor card** — tappable; "Family Doctor:" label; navigates to Medic tab
- **Specialist screens** — all 8 specialties show real doctor names from Practitioners constants
- **My Profile** — save SnackBar (brand blue); blue back button; avatar sync to dashboard via patientAvatarProvider
- **Triage chat** — first patient message + AI first response seeded as bubbles on MedicalResponseScreen entry
- **Doctor message flow** — clean entry with no pre-populated bubble; AppBar shows doctor name; welcome card shows neutral context
- **Dosar Medical** — audio and photo attachment paths serialized into FHIR note text; restored as playable/tappable bubbles on replay

### BUILT — AWAITING DEVICE TEST

- **Mock patient DB (5 patients)** — `FhirEngineChannel.kt` seeds 5 realistic Romanian patients (Maria Ionescu CNP 2540203150013, Ion Popescu CNP 1490815150027, Elena Dumitrescu CNP 2621105150032, Gheorghe Stan CNP 1551220150048, Ana Constantin CNP 2480430150058) each with valid checksum CNP, name, DOB, phone, and one clinical Condition (Hipertensiune / Diabet tip 2 / Artrită / Insuficiență cardiacă / BPOC)
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
- **AppointmentsScreen (Programări)** — table_calendar 3.2.0, ro_RO locale; FHIR Appointment CRUD (saveAppointment / getAppointments scoped by Patient CNP); inline booking panel (hardcoded slots MVP); appointment cards with status chips (Confirmată/Finalizată/Anulată); "Intră în consultație" → WaitingRoomScreen with appointmentId; "Solicită programare nouă" → inline panel; real Practitioner IDs from `Practitioners` constants (M3)
- **SpecialistsScreen (Specialiști)** — 8 specialties (Cardiologie, Neurologie, Dermatologie, Ortopedie, Oftalmologie, Pediatrie, Psihiatrie, Ginecologie); diacritic-insensitive search filter; 2-column grid; taps → DoctorProfileScreen(specialist variant); Dr. Andrei Popescu hardcoded for Pediatrie; other specialties use placeholder name pending Medplum Practitioner data
- **WaitingRoomScreen (compound — A5)** — replaces stub; two-state AnimatedSwitcher (consent → buffer); STATE A: consent card, "Sunt de acord" → STATE B; STATE B: video preview (local only, no signaling), mic/video toggle, private-space checkbox, "Intră în apel" → VideoConsultationScreen; "Anulează" exits; doctorName param replaces hardcoded name; appointmentId param wired from AppointmentsScreen
- **Device bug fixes (F1–F6, G1–G5)** — i18n badges translated (RO/EN); navigation routing fixed (specialists, specialist doctor sub-screens, footer link); Dosar Medical refreshes post-finalize without login; appointments scoped per Practitioner; doctor name + specialty on appointment cards; calendar starts Monday; language toggle on profile completion screen; message categorization by doctor + AI category chip (medical/document/other); WaitingRoom button swap fixed; in-call chat local state wired
- **MedplumAuthService (M1)** — OAuth2 client_credentials token fetch against `https://telemed-medplum.duckdns.org/oauth2/token`; 3-tier resolution (in-memory cache → flutter_secure_storage → POST to token endpoint); 60-second expiry buffer; `clearToken()`; `isOnline()` via connectivity_plus; `medplumAuthServiceProvider` singleton Provider
- **MedplumRepository (M2)** — 9 REST FHIR methods against `https://telemed-medplum.duckdns.org/fhir/R4`; online-first reads with local FHIR SDK offline fallback; dual-write on all save/update operations (Medplum best-effort + local guaranteed); FhirRepository method signatures unchanged; `medplumRepositoryProvider` injected into `fhirRepositoryProvider`
- **Practitioner constants (M3)** — `lib/core/constants/practitioner_constants.dart` with real Medplum IDs; 11 hardcoded strings replaced across 7 files; `"family"` practitionerRef eliminated; `"Mariana Andronescu"` → `Practitioners.familyDoctorName`; `"specialist_pedia"` → `Practitioners.bogheanuId`; backwards-compatible appointment card name resolution
- **Security fixes R1–R8** — R1: OAuth credentials moved to `--dart-define` (no literals in source); R2: `network_security_config.xml` created, `usesCleartextTraffic` removed, `READ_MEDIA_IMAGES` confirmed, `WRITE_EXTERNAL_STORAGE` dead code removed; R3: 2 hardcoded Romanian strings extracted to AppStrings; R4: mic/camera/text handlers wrapped in try/catch + `ref.listen` for error state in home screen; R5: `FhirRepository` read methods now return safe empty values instead of throwing; R6: `aiReadyProvider` invalidated after model deletion (confirmed already in place); R7: resource disposal verified (no gaps); R8: `DoctorProfileScreen` intentional non-route comment added, time-padding consolidated into `DateFormatter` (3 call sites)
- **H4 — Legal screens via WebView** — `LegalContent.dart` stores full Stitch HTML with green→#5BA4CF replacement; `webview_flutter: ^4.10.0` added; `LegalDocumentModal` renders via `WebViewController.loadHtmlString`; OTP screen buttons call `LegalDocumentType.terms/privacy`; language switch works
- **H5 — Back button on triage + Trimite mesaj AI routing** — `PopScope(canPop:false)` + 64dp AppBar back button on home/triage screen; `_onBack()` navigates to dashboard (idle) or shows exit dialog (active session); `MedicalResponseScreen.initialPrompt` auto-triggers AI inference; family doctor "Trimite mesaj" uses `Navigator.push` + `initialPrompt`
- **H6 — Consent screen layout fix** — WaitingRoomScreen STATE A: "Vă rugăm să citiți..." subtitle inside consent card (16sp italic); STATE B checkbox redesigned (#EBF4FB background, 2px #5BA4CF border, full-row GestureDetector, 64dp min height)
- **H8 — Voice recording confirmation dialog** — First mic tap shows AlertDialog (48dp mic icon, 64dp stacked buttons); cancel does nothing; stop tap skips dialog
- **H12 — WebRTC signaling server** — Node.js relay at GX10:8765 (`/home/corb_d/sovereign-factory/signaling/server.js`); rooms keyed by appointmentId; Flutter ICE config updated with STUN + TURN (coturn pending GCP install)
- **H13 — Doctor browser UI** — `doctor-ui/index.html`; Medplum client_credentials auth + today's appointment list from FHIR; manual entry fallback; join wires to signaling room
- **H3 — Ajutor button with ML Kit OCR + voice** — `OcrChannel.kt` (ML Kit `TextRecognition`); `OcrService.dart` with `parseCnp()`/`parsePhone()` regex; 15-second countdown dialog; model-not-ready guard; awaiting device test of camera OCR path (ML Kit first-launch warm-up under test)
- **H7 — In-call chat panel** — `DraggableScrollableSheet` (45%–85% height) overlaid on video; text + file messaging; FHIR Communication via `MedplumRepository.saveCommunication()`; `appointmentId` forwarded end-to-end; Gemma 4 summary on call end
- **H9 — Document attachment + voice replay + image preview** — `file_picker: ^8.1.2` + `just_audio: ^0.9.42` added; `AttachmentType` enum + `attachmentPath` in `ChatMessage`; `_onAttachDocument()` in `MedicalResponseScreen`; inline audio playback; full-screen `InteractiveViewer`; `saveDocumentReference` in MedplumRepository
- **H11 — Medplum sync verification + appointmentId fix** — HTTP 200 confirmed; `saveCommunication` + `saveDocumentReference` present; `Communication.about` populated; GitHub Actions secrets pending manual setup

### PENDING IMPLEMENTATION

- **Async messaging thread (Trimite mesaj flow)** — patient ↔ doctor text thread initiated from Medic tab; threaded UI with timestamps; push notification delivery via FCM when online
- **AI assistant as persistent channel monitor** — Gemma 4 monitors all voice/text/photo triage, messaging, and consultation history; routes urgent cases toward 112; surfaces clinical insights across sessions
- **Phone number change + device transfer flow (B0)** — new device account creation route; transfers all FHIR data to new device on phone number change; requires new Stitch screens; blocked in PatientProfileScreen with "Funcție în curând disponibilă" dialog

### BUGS FOUND DURING DEVICE TEST (2026-05-05) — FIXED

- **Button label after first login** — OTP confirm button always said "Create account" even for returning users; fixed with SharedPreferences `account_created` flag; label now switches to "Enter account" on return visits
- **Empty active treatment on dashboard** — label was "Treatment" placeholder; now shows "No active treatment" / "Niciun tratament activ" via `dashboard.no_active_treatment` key
- **Message button label** — button showed "Send message"/"Trimite mesaj"; shortened to "Message"/"Mesaj" via `doctor.message_btn` key
- **"Dr. Dr." duplication** — `doctor.message_preseed` contained "Dr. [name]" while name constants already include "Dr."; fixed by removing "Dr." prefix from the template
- **Help panel overflow 57px** — bottom sheet padding/borderRadius fix; `isScrollControlled:false`, horizontal padding 16dp, radius 20dp
- **In-call chat text invisible** — TextField style missing `color: Color(0xFF1a1c1c)` + `filled:true`/`fillColor:Colors.white`; fixed
- **In-call chat sheet no dismiss on tap-outside** — added `DraggableScrollableController` with `GestureDetector` overlay + listener collapses on drag to minChildSize:0.0
- **In-call chat bottom overflow 256px** — `resizeToAvoidBottomInset:true` on Scaffold + `SafeArea(top:false)` on sheet Column
- **Attach file didn't open chat panel** — `_attachCallFile()` now sets `_chatOpen=true` before FilePicker if panel is closed
- **OCR infinite loading (ML Kit timeout)** — `OcrChannel.kt` now wraps `suspendCancellableCoroutine` in `withTimeout(15_000L)`; Dart shows `ocr.timeout_error` SnackBar on empty result
- **Voice help wrong field + extra digits** — AI result now validated via `^\d{13}$` (CNP) and `^07\d{8}$` (phone) before filling fields; `ocr.voice_parse_error` shown on invalid
- **Duplicate Dosar Medical entries** — `_finalized` bool added to both `MedicalSessionNotifier` and `_MedicalResponseScreenState`; `finalizeConsultation()` returns early on second call
- **Continue conversation red screen** — `DialogDetailSheet` now uses `Navigator.push(MedicalResponseScreen(...))` instead of flat nav; bypasses session-guard race condition
- **Appointments section on dashboard** — renamed to "Appointments/Programări"; tappable → AppointmentsScreen; appointment time UTC→local fix in `DateFormatter.format` (`dt.toLocal()`)
- **Appointment time always 07:30** — `DateFormatter.format` was using `dt.hour` on a UTC DateTime; now calls `dt.toLocal()` before extracting hours
- **Doctor UI no patient list** — replaced manual code entry with Medplum client_credentials auth + today's appointment list from `GET /fhir/R4/Appointment?date=today`; manual entry kept as fallback
- **Medplum patient creation silent failure** — added 401 retry (clearToken + getValidToken); detailed logging for each failure mode; local FHIR write never blocked

### STILL BROKEN / SKIPPED FOR HACKATHON

- **LiteRT-LM actual on-device inference** — model in `filesDir/models/`; `initializeModel()` wired; AI status indicator will show green if init succeeds — **not yet observed on device**
- **Text card → inference** — `handleRunInference` implemented in Kotlin; end-to-end path from text card UI → MethodChannel → model output not yet device-tested
- **Medplum device sync** — auth wired with dart-define (R1); GitHub Actions secrets not yet added; actual on-device sync test pending
- **TURN server** — coturn config written; pending manual install on GCP VM (no SSH key from GX10); Flutter + doctor UI ICE config already updated
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
| lib/core/services/medplum_auth_service.dart | OAuth2 client_credentials token fetch + 3-tier cache + flutter_secure_storage (M1) |
| lib/core/services/medplum_repository.dart | Medplum REST FHIR client — 9 methods, online-first reads, dual-write (M2) |
| lib/core/providers/medplum_auth_provider.dart | medplumAuthServiceProvider + medplumRepositoryProvider (M1/M2) |
| lib/core/constants/practitioner_constants.dart | Real Medplum Practitioner IDs + display names (M3) |
| lib/core/providers/auth_provider.dart | patientAuthProvider + patientAvatarProvider (NotifierProvider<Uint8List?>) — in-memory avatar bytes, never persisted to disk |
| DESIGN.md | The Dignified Guardian design system (permanent reference) |
| doctor-ui/index.html | Full doctor interface: sliding panel (Appointments / Patient Report / In-Call), patient triage report with Mark reviewed + Finalize, in-call Chat + Activity tabs |

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
| android/.../AndroidManifest.xml | All permissions; network_security_config (cleartext blocked); READ_EXTERNAL_STORAGE ≤32 |

---

## Device Info

| Item | Value |
|---|---|
| Test device | Google Pixel 9 Pro (serial: 4C041FDAP006Z1) |
| Model file location | /sdcard/Download/gemma-4-E2B-it.litertlm |
| ADB | USB cable (unreliable); wireless not configured |
| Install method | Download APK from GitHub Actions artifact on phone browser |
| GX10 model server | https://telemed-b.duckdns.org (production) / 192.168.0.144:443 (LAN direct) |

---

## Infrastructure

### GCP Reverse Proxy VM
- **VM:** telemed-proxy, e2-micro, Frankfurt (34.185.191.34)
- **Services:** caddy.service + wg-quick@wg0.service
- **Caddy config** (routes all domains through WireGuard tunnel):
    telemed-b.duckdns.org → reverse_proxy https://10.0.0.2:443
      (tls_server_name: telemed-b.duckdns.org)
    telemed-medplum.duckdns.org → reverse_proxy 10.0.0.2:8103
    telemed-medplum-ui.duckdns.org → reverse_proxy 10.0.0.2:8104
    telemed-doctor.duckdns.org → reverse_proxy https://10.0.0.2:443
      (tls_server_name: telemed-doctor.duckdns.org) — Doctor WebRTC UI
    telemed-signal.duckdns.org → reverse_proxy 10.0.0.2:8765 — WebSocket signaling relay
- **WireGuard:** VPS peer 10.0.0.1 ↔ GX10 peer 10.0.0.2
  wg-quick@wg0.service on both ends

### GX10 Services
- **GX10 LAN IP (WiFi):** 192.168.0.101
- **GX10 LAN IP (Ethernet):** 192.168.0.144 — interface `enP7s7`; no `tc` rate limiting
- **caddy-telemed.service** — serves telemed-b.duckdns.org + telemed-doctor.duckdns.org +
  telemed-signal.duckdns.org on port 443; Caddy 2.11.2 ARM64; TLS via DuckDNS DNS-01
- **wg-quick@wg0.service** — WireGuard tunnel to GCP VM
- **medplum systemd service** — Docker Compose via sovereign-factory/ directory
- **telemed-signaling.service** — Node.js WebRTC signaling relay; ws://0.0.0.0:8765;
  `/home/corb_d/sovereign-factory/signaling/server.js`; relay-only, rooms keyed by appointmentId;
  external URL: wss://telemed-signal.duckdns.org (via Caddy + WireGuard)
- **Doctor UI** — static HTML served by caddy-telemed from
  `/home/corb_d/sovereign-factory/doctor-ui/index.html`;
  URL: https://telemed-doctor.duckdns.org; vanilla JS WebRTC client, joins signaling room by appointmentId
- **Router port forward:** TCP 443 → 192.168.0.101:443 on TP-Link AX5400

### Medplum (Self-Hosted FHIR Server)
- **Version:** 5.1.10
- **Compose services:**
  | Container | Image | Port |
  |---|---|---|
  | medplum-server | medplum/medplum-server:latest | 0.0.0.0:8103→8103 |
  | medplum-app | medplum/medplum-app:latest | 0.0.0.0:8104→3000 |
  | medplum-redis | redis:7-alpine | internal |
  | medplum-postgres | postgres:16-alpine | internal |
- **Storage:** Docker named volumes (medplum-pgdata, medplum-storage)
- **Endpoints:**
  FHIR Base: https://telemed-medplum.duckdns.org/fhir/R4
  Auth Token: https://telemed-medplum.duckdns.org/oauth2/token
  Admin UI:   https://telemed-medplum-ui.duckdns.org
  Metadata:   https://telemed-medplum.duckdns.org/fhir/R4/metadata
- **Project:** TeleMed Bogheanu (ID: 7b4bc928-abd8-4332-b6f5-a9cae5737fa8)
- **Admin:** admin@telemed-bogheanu.ro / TeleMed_Sovereign_2026!

### Medplum Flutter Client
- **Client ID:** d5d39070-c8a4-43a6-92e5-1a78b695ca72
- **Client Secret:** TeleMed_K_Client_Secret_2026!
- **Grant type:** client_credentials (hackathon); PKCE auth_code (future)
- **Redirect URI:** com.example.telemed_k://callback

### Medplum Seeded Data
Patients (CNP → FHIR ID):
  Maria Ionescu     2540203150013 → Patient/a0e44abc-acc5-442e-a316-be70192fc72b
  Ion Popescu       1490815150027 → Patient/118149bf-26e0-46e1-87de-7149e8066284
  Elena Dumitrescu  2621105150032 → Patient/510b8c93-ef4a-43bc-b265-197fcfc03c2b
  Gheorghe Stan     1551220150048 → Patient/6955bb14-46d7-4a9b-b7a4-d98e95051f3f
  Ana Constantin    2480430150058 → Patient/40d2b51f-5a36-4e13-9755-5e7b6bb9ba85

Demo OTPs (last 6 digits of each CNP):
  Maria Ionescu:    150013
  Ion Popescu:      150027
  Elena Dumitrescu: 150032
  Gheorghe Stan:    150048
  Ana Constantin:   150058

Conditions:
  Hipertensiune arterială     → Condition/36d3b343 → Maria Ionescu
  Diabet zaharat tip 2        → Condition/1b02b21e → Ion Popescu
  Artrită reumatoidă          → Condition/59f9db2b → Elena Dumitrescu
  Insuficiență cardiacă       → Condition/9feb7821 → Gheorghe Stan
  Boală pulmonară obstructivă → Condition/e7161115 → Ana Constantin

Practitioners:
  Dr. Elena Ionescu   Family Doctor (Medic de Familie)        Practitioner/733e1972-b42d-4bd0-82c7-66db72b2d311
  Dr. Andrei Popescu  Pediatrician specialist (Pediatrie)     Practitioner/474f526b-7919-48dd-9528-3c0eaff80cb6
Note: Dr. Elena Ionescu is the family doctor shown in the Medic tab (MyDoctorScreen).
      Dr. Andrei Popescu is the pediatric specialist shown in SpecialistsScreen → Pediatrie.
      Both roles are correctly set in `lib/core/constants/practitioner_constants.dart`.

FHIR search patterns:
  Patient by CNP: GET /fhir/R4/Patient?identifier=urn:oid:1.2.40.0.10.1.4.3.1|{CNP}
  Condition by patient: GET /fhir/R4/Condition?subject=Patient/{id}
  Appointments by doctor: GET /fhir/R4/Appointment?actor=Practitioner/{id}
  CNP identifier system: urn:oid:1.2.40.0.10.1.4.3.1

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
- **Per-doctor appointment scoping** — FHIR Appointment stores practitionerRef per resource. Patient sees all their appointments; each doctor (Medplum) sees only their own. Real Practitioner IDs defined in `Practitioners` constants: family doctor = `Practitioners.familyDoctorId`; Dr. Bogheanu (Pediatrie) = `Practitioners.bogheanuId`.
- **Medplum sync layer (M2)** — `FhirRepository` is the single access point. When online, reads go to Medplum first and fall back to local FHIR SDK. Writes always hit both (dual-write). Method signatures unchanged; all existing callers are unaffected.
- **WaitingRoomScreen is compound** — consent state + buffer state in one screen, switched by AnimatedSwitcher. Entry: AppointmentsScreen "Intră în consultație". Exit chain: → VideoConsultationScreen.
- **Phone change blocked pending B0** — PatientProfileScreen allows typing a new phone number but blocks save with a dialog. Full device-transfer flow requires new Stitch screens and is tracked as B0.
- **patientAvatarProvider** (`NotifierProvider<_AvatarNotifier, Uint8List?>`) in auth_provider.dart — in-memory only; shared between PatientProfileScreen and DashboardScreen for live avatar propagation without touching PatientAuthState; bytes are never written to SharedPreferences or plain files.
- **MedicalSessionState.lastPractitionerRef** — tracks which practitioner a session is routed to; written as `reviewed-by-target` FHIR extension on `finalizeConsultation`; defaults to `Practitioners.familyDoctorId` if null; propagated through all 5 state copy sites.
- **session-category canonical extension URL:** `https://telemed-bogheanu.ro/fhir/ext/session-category` — all FHIR extension reads use `endsWith`/`contains` matching for URL resilience.
- **Doctor UI sliding panel** — 3 states (Appointments / Patient Report / In-Call); Mark reviewed → PATCH `reviewed-by` extension; Finalize → PATCH `status:final` on all reviewed Observations in session; responsive design (320px desktop, 280px tablet overlay, full-width mobile).
- **WaitingRoomScreen STATE B activity panel** — "See my recent activity" button shows last 5 Observations from local FHIR SDK; read-only; shows date, category chip (session-category extension), and AI summary excerpt.
- **VideoConsultationScreen Activity tab** — alongside Chat tab in DraggableScrollableSheet; last 5 Observations loaded on `initState` via `_loadActivityData()`; read-only cards; fail-silent with `debugPrint`.

---

## Code Quality

Four full audit cycles completed (2026-05-02, 2026-05-04, 2026-05-05, 2026-05-06). All findings resolved: audit round 4 found 0 critical + 1 high + 11 medium + 5 low — all fixed. Current state: **0 critical, 0 high, 0 medium, 0 low** open issues.
Post-hackathon deferred: duplicate Observation schema between `finalizeConsultation()` and `VideoConsultationScreen._saveCallSummary()` (refactor to shared factory method).

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
- [x] GCP e2-micro reverse proxy + WireGuard tunnel (telemed-proxy, Frankfurt) — routes telemed-b, telemed-medplum, telemed-medplum-ui through WireGuard to GX10
- [x] Medplum 5.1.10 self-hosted on GX10 — FHIR R4 live at https://telemed-medplum.duckdns.org/fhir/R4/metadata
- [x] Medplum seeded — 5 patients, 5 conditions, 2 practitioners
- [x] Device bugs F1–F6 + G1–G5 fixed
- [x] MedplumAuthService — client_credentials OAuth2 token fetch + flutter_secure_storage (M1)
- [x] MedplumRepository — 9 REST FHIR methods, online-first, dual-write (M2)
- [x] Replace all hardcoded practitionerRefs with real Medplum IDs (M3)
- [x] R1: OAuth credentials moved to dart-define; `defaultValue: ''` fallback; `.github/workflows/build-apk.yml` updated; `.env.example` created
- [x] R2: `network_security_config.xml` created; `usesCleartextTraffic` removed; `READ_MEDIA_IMAGES` confirmed; `WRITE_EXTERNAL_STORAGE` removed
- [x] R3: 2 hardcoded Romanian strings extracted (`profil.phone_change_body`, `appointment.select_slot`)
- [x] R4: Mic/camera/text handlers wrapped in try/catch; `ref.listen` for `SessionState.error` in home screen
- [x] R5: FhirRepository read methods return safe empty values on `PlatformException` instead of throwing
- [x] R6: `aiReadyProvider` invalidated after model deletion (already in place — confirmed)
- [x] R7: Resource disposal gaps verified as non-issues; `_pulseController.dispose()` confirmed
- [x] R8: `DoctorProfileScreen` intentional non-route comment; time zero-padding consolidated into `DateFormatter` (3 methods: `formatTime`, `formatDuration`, `formatTimeOfDay`)
- [x] H1: Language toggle on login identity screen; `nav.back` key added
- [x] H2: 5 checksum-valid CNPs (county 15); seed data updated; `tools/update_medplum_cnps.dart` script
- [x] H3: ML Kit OCR (`OcrChannel.kt` + `OcrService.dart`); 15s voice countdown dialog; model-not-ready guard; login `_extractViaCamera()` now real OCR (no more `dummy_id.jpg`)
- [x] H4: Legal screens via WebView; `LegalContent.dart`; green→blue HTML cleanup; `webview_flutter` added
- [x] H5: Back button + PopScope on triage screen; `MedicalResponseScreen.initialPrompt`; Trimite mesaj via Navigator.push
- [x] H6: Consent subtitle repositioned inside card; checkbox redesigned brand-blue
- [x] H7: In-call chat DraggableScrollableSheet; FHIR Communication; Gemma 4 summary on call end; `appointmentId` forwarded end-to-end
- [x] H8: Voice recording confirmation dialog (elderly-friendly, 64dp buttons)
- [x] H9: Document attachment + audio replay + image fullscreen; `file_picker` + `just_audio` added; `AttachmentType` enum; `saveDocumentReference` in MedplumRepository
- [x] H11: `appointmentId` wired VideoConsultationScreen; `Communication.about` field populated; Medplum connectivity confirmed HTTP 200

### P1 — NEXT
- [ ] **Make GitHub repo public before May 18 deadline** — currently PRIVATE; required for hackathon submission
- [ ] **Record competition demo video** — patient story: Maria, 72, chest pain, no car → voice triage → 112 or teleconsult
- [ ] **Add GitHub Actions secrets** — `MEDPLUM_CLIENT_ID` + `MEDPLUM_CLIENT_SECRET` at Settings → Secrets → Actions (see H11 instructions)
- [ ] **Device test all H1–H9 + H11 items** — install latest APK on Pixel 9 Pro; verify each BUILT item above
- [ ] Device test Medplum sync — verify online writes reach https://telemed-medplum.duckdns.org/fhir/R4 and are visible in Medplum admin UI
- [ ] Wire Medplum patient lookup in auth flow — replace local FHIR SDK seed with Medplum Patient search by CNP
- [ ] End-to-end text card inference device test (handleRunInference → model output)
- [x] WebRTC signaling server on GX10 — deployed (H12); telemed-signal.duckdns.org relay live

### P2 — NEXT
- [x] Real camera OCR in login — ML Kit OcrChannel.kt implemented (H3); `dummy_id.jpg` replaced
- [ ] Phone change + device transfer flow (B0) — requires new Stitch screens before implementation

### P3 — NEXT
- [ ] DeviceConflictModal trigger from auth flow

---

## Hackathon

- **Deadline:** May 18, 2026 — **12 days remaining**
- **Public repo required:** currently PRIVATE — must make public before deadline
- **Demo video:** not yet recorded
- **Gemma 4 on-device status:** CONFIRMED WORKING — Gemma 4 E2B responds to text and voice on Pixel 9 Pro; language toggle works; conversation context maintained
- **Latest tested build:** #64 (commit fb1a104) — installed on Pixel 9 Pro 2026-05-05
- **Medplum status:** CONFIRMED WORKING — client_credentials auth working; appointments/observations/communications syncing; doctor UI showing live data
- **WebRTC status:** CONFIRMED WORKING — two-device video call end-to-end tested
- **Known open issues:** see HANDOFF.md Outstanding Bugs P1/P2 list

## Patient Demo Story (for competition video)
Maria, 72, Brănești, chest pain, no car, hospital 40km away.
Opens TeleMed_K → voice/photo/text triage → Gemma 4 analyzes on-device →
urgency detected → one tap calls 112 OR books teleconsultation with Dr. Bogheanu.
NGO provides the device itself for patients who cannot afford one.
