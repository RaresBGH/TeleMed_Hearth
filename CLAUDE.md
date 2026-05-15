# TeleMed Hearth — Claude Code Session Context

## Project
Flutter telemedicine app for rural Romania. Dr. Bogheanu clinic in Brănești, Dâmbovița.
Hackathon: Kaggle Gemma 4 Good — deadline May 18, 2026.
Repo: https://github.com/RaresBGH/TeleMed_K (private until near deadline)

## Hardware
GX10 (ARM64, 128GB, NVIDIA GB10) — sovereign AI server
Pixel 9 Pro (device ID: 4C041FDAP006Z1) — test device, USB or wireless ADB
Flutter 3.44.0 master channel at /snap/bin/flutter

## Infrastructure
Caddy v2.11.2 serving model at https://telemed-b.duckdns.org
Model: /home/rares_bogheanu/gemma-4-E4B-it.litertlm (3.5GB) — on GCP VM, served by Caddy file_server
Caddy systemd service: caddy-telemed (sudo systemctl status caddy-telemed)
GX10 ethernet IP: 192.168.0.144 (enP7s7) — no rate limiting
DuckDNS token: stored as DUCKDNS_TOKEN env in caddy-telemed.service
GCP reverse proxy VM: telemed-proxy, e2-micro, Frankfurt (34.185.191.34)
WireGuard tunnel: GCP peer 10.0.0.1 ↔ GX10 peer 10.0.0.2 (wg-quick@wg0 on both)
GCP VM Caddy (telemed-proxy): running as PID outside systemd — use `sudo caddy reload --config /etc/caddy/Caddyfile`, NOT systemctl. The `caddy-telemed` systemd service above is the GX10's own Caddy only.
Medplum FHIR: https://telemed-medplum.duckdns.org/fhir/R4 (Medplum 5.1.10, self-hosted on GX10)
Medplum admin: admin@telemed-bogheanu.ro / TeleMed_Sovereign_2026!
Medplum client ID: c18b54d9-f511-46db-903e-882b47dc3c63
Medplum client secret: 7f86f3b5c08e94d711f61a4565c7d577cb303e78a5d57b5d340b74baf8c0b283
Medplum project: 7b4bc928-abd8-4332-b6f5-a9cae5737fa8

## Working Rules (MANDATORY)
1. VERIFY before acting — read the file before editing it
2. ONE step at a time — never assume previous steps succeeded
3. FINISH MESSAGE required on every task — format: "TASK_NAME — key: value — key: value — analyze errors: N"
4. BEFORE EVERY COMMIT — run: flutter analyze --no-pub 2>&1 | grep -E 'error|warning' | head -20 — fix all errors before committing. Warnings are acceptable, errors are not.
5. Never guess — if unsure, say so and ask for guidance
6. Clean up failed attempts before retrying

## Tech Stack
- Flutter/Dart + Kotlin native Android
- LiteRT-LM 0.11.0 (Gemma 4 E4B on-device inference)
- Google Android FHIR SDK 1.2.0 + SQLCipher (local encrypted storage)
- OkHttp (model download with resume)
- Riverpod (state management)
- compileSdk=36, minSdk=28, NDK=27

## Key Architecture Decisions
- Model downloads post-auth to filesDir via OkHttp foreground service
- All inference isolated per session (fresh Conversation per call)
- Single FHIR Observation per dialog, saved only on explicit "Finalizează Dialogul"
- Language switching via AppStrings (120 keys, reactive, no restart)
- Mock patient DB: 4 patients seeded in FhirEngineChannel.kt (Maria/Ion/Sarah/George)
- Shared bottom nav widget: AppBottomNavBar (Acasă / Dosar Medical / Medic)
- Medplum sync layer: FhirRepository online-first reads + dual-write; local FHIR SDK is offline cache
- Practitioner IDs in lib/core/constants/practitioner_constants.dart — never hardcode
- patientAvatarProvider (NotifierProvider<Uint8List?>) in auth_provider.dart — shared between PatientProfileScreen and DashboardScreen for live avatar propagation; in-memory only, never persisted to disk
- lastPractitionerRef in MedicalSessionState — tracks doctor context across all 5 state copy sites; written as reviewed-by-target FHIR extension on finalizeConsultation; defaults to Practitioners.familyDoctorId
- session-category canonical extension URL: https://telemed-bogheanu.ro/fhir/ext/session-category — all FHIR extension reads use suffix/contains matching
- FHIR PATCH: always use application/json-patch+json (RFC 6902 array) — Medplum 5.1.10 rejects merge-patch with 400
- finalizeConsultation _finalized: reset as first line of reset() before stopAndRelease() — prevents audio exceptions blocking future FHIR writes
- patientHistoryProvider: invalidated inside notifier after successful FHIR write via try { ref.invalidate(...) } catch (_) {}
- Bottom nav: localised via languageProvider + AppStrings (nav.home / nav.dossier / nav.doctor), reactive to EN/RO toggle
- Doctor Communications: getCommunications() in MedplumRepository + FhirRepository; saveCommunication() includes sender/recipient FHIR fields; doctor messages surface in MedicalResponseScreen as green 'doctor' role bubble
- VideoConsultationScreen: in-call chat removed — Activity tab only (observations); _callMessages and WebSocket chat send removed
- Doctor UI: Appointments panel state removed; in-call panel shows Patient Report read-only; Chat state is async Medplum-only (no WebSocket); blue Chat stripe opens chat outside call
- AppointmentsScreen: showBookingButton=false by default (read-only from dashboard); screenTitle parameter for contextual title; family doctor scoped to familyDoctorId explicitly
- Doctor profile: specialty shown as AppBar top label; entitlement string (from Practitioners.*entitlement) shown below name
- Medplum-first reads: getMostRecentEncounter uses fulfilled Appointments; getMostRecentMedicationRequest and getPatientHistory (Conditions + Observations) all online-first with local fallback
- _patientLanguage map in PatientAuthNotifier: CNP→lang lookup for auto language switch at login; AI engine language synced via HomeScreen initState() post-frame callback
- AI inference: systemPromptOnly separate from conversationContext; NO customPrompt for audio/photo evaluations (causes context overflow with E4B); history capped at 10 messages; 3 Observations max in FHIR context; turn counter in conversation header
- 5-question limit: in system prompt both EN/RO; turn counter in conversation header; ready_to_finalize kept true after summary delivered
- Clinical summary: generated at finalization via evaluateText(history + summaryRequest, no customPrompt); stored as Observation.valueString; displayed as "Clinical Summary"/"Rezumat Clinic" in Dossier
- Audio: WAV → inference, AAC → playback; updateAudioPath() stores AAC after transcoding; home screen audio path fixed via updateAudioPath() in home_screen.dart
- Photo: permanent copy made before temp deletion for both home screen and in-chat; existsSync removed (direct try/catch copy); updateImagePath() stores permanent path
- Doctor UI: credentials injected at deploy time only (never in source); clinical summary from obs.note last [AI] line; expand conversation toggle; back to appointments button; peer left overlay fully opaque black
- WebRTC: 640×480 @ 24fps, 500kbps both sides; confirmed stable 5+ minutes laptop+phone
- Dialogue numbering: oldest=#1 in history_screen.dart; passed to DialogDetailSheet as optional param

## Open Issues (carry to next session)

### P0 — RESOLVED
- C1 (_dependents.isEmpty + deactivated ancestor): debug-only Flutter assertion. Release build confirmed working (build #102). Not user-facing. Multiple root causes addressed across builds #81–#90.
- Release APK crash on inference: RESOLVED build #102 — ProGuard keep rules for LiteRT-LM JNI callbacks (R8 was renaming onMessage/onDone, causing NoSuchMethodError).
- Release APK model download DNS failure: RESOLVED build #99 — network_security_config.xml domain-config for duckdns.org.

### P1 — CONFIRMED WORKING ON DEVICE (#110 + #112)
- Auto language switch on login (Maria/Ion→RO, Elena/George→EN) ✓ (#110)
- Dashboard data correct per patient (condition/medication/appointment) ✓ (#110)
- Voice bubble playback (AAC path fix) ✓ (#110)
- Photo suggestion by AI (conditional — only when no photo sent yet) ✓ (#110)
- Info card in chat (dismissible) ✓ (#110)
- Dialogue numbering in Dossier (#1, #2…) ✓ (#110)
- Clinical Summary label in Dossier ✓ (#110)
- Conversation continuation from Dossier ✓ (#110)
- Video call stable 5+ minutes (laptop Brave + Pixel 9 Pro) ✓ (#110)
- Appointment status labels (Completed/Cancelled/Missed) ✓ (#110)
- Past appointments hide Enter button ✓ (#110)
- Join window -60/+120min ✓ (#110)
- Dr. name resolved in Communications bubbles ✓ (#110)
- Activity panel title added ✓ (#110)
- Mic released after video call ✓ (#110)
- All 4 patients correct in Medplum ✓ (#110)
- All 9 practitioners named in Medplum ✓ (#110)
- Fix #1: state corruption recovery (no English fallback) ✓ (#112)
- Fix #2: EN system prompt parity ✓ (#112)
- Fix #3: EN no-diagnosis safety clause ✓ (#112)
- Fix #4: voice-in-chat conversation history ✓ (#112)
- Fix #6: photo inference 1024px resize ✓ (#112)
- Fix #10: Programări back-navigation ✓ (#112)
- Tab navigation (Medic, Specialiști) ✓ (#112)

### P1 — PENDING (test on #113 device install)
- Finalize button spinner hangs indefinitely (#112 regression; Fix #19 guard + Fix #11 timeout applied in #113)
- Activity panel still won't dismiss (#112 regression; Fix #14 SurfaceView removal applied in #113)
- Peer-left overlay frozen frame (#112 regression; Fix #15 connection-state listeners + objectFit applied in #113)
- Clinical summary shows wrong content in Doctor UI (#112; Fix #12 [AI]-line append applied in #113)
- Raw Android file paths in Doctor UI transcript (#112; Fix #13 localized labels applied in #113)
- New appointment not in list until restart (#112; Fix #16 _hasLoaded reset applied in #113)
- "Recent Health Status" EN in RO session (#112; Fix #17 AppStrings routing applied in #113)
- First-input loading-state greeting mismatch (#112; Fix #18 state-gated copy applied in #113)
- 5-question limit still ignored by model — sampling applied (Fix #7) but model compliance unverified; accepted limitation for demo; choreograph script to finalize around question 4–5
- Doctor UI controls layout: Unmute cut off at left edge — accepted cosmetic for demo
- Ion/Sarah (#112 device): empty Recent Activity — seeded 2 Observations + 1 Appointment each in Medplum (curl, no commits)

### P1 — STILL OPEN (post-hackathon)
- Emergency routing: EmergencyScreen → tel:112 — device test pending
- Fine-tuned adapter deployment: Path A1 blocked (MediaPipe no Gemma 4); litert-torch hf_export.export() supports Gemma 4 text-only but vision encoder LoRA merge unsupported; revisit post-hackathon
- withOpacity→withValues migration pending CI upgrade past Flutter 3.32.x
- Token refresh hardening for >1hr judge sessions
- Login flow: Medplum CNP search at auth (currently local FHIR SDK only)
- Duplicate Observation schema between finalizeConsultation and VideoConsultationScreen._saveCallSummary
- JSONL debug log rotation (currently unbounded)
- Doctor UI Unmute button layout polish

## Current State
See TELEMED_CONTEXT.md for full verified/awaiting-test/broken breakdown.
Last updated: 2026-05-15
Latest build: #113 (staged locally; commit 95eda78 covers fixes #11–#20).
Last device-tested: #112 release.
3 days to deadline (May 18, 2026).
App name: TeleMed Hearth.
Repo: PRIVATE — must go public before May 18.
Demo-day morning: verify Patient ID Case 1, seed Ion's 10:00 appointment, full #113 regression test.

## ADB Commands
adb -s 4C041FDAP006Z1 logcat -d | grep -E "LiteRtLm|flutter|com.example.telemed_k" | tail -40
adb -s 4C041FDAP006Z1 shell pm clear com.example.telemed_k && adb -s 4C041FDAP006Z1 uninstall com.example.telemed_k

## Code Quality
Audit round 4 completed 2026-05-06. All findings resolved.
Build #75 batch: 25+ fixes across appointments, dashboard, doctor UI, video call, chat, PDF/image transfer. 0 analyze errors.
Additional fixes: join window corrected (-60min/+120min); dashboard appointment filter broadened (booked+confirmed, within 2h past); 'Family Doctor' → 'Family Medicine'; doctor UI isCallActive guard, frozen video clear on peer exit, redundant PANEL tab removed; fulfilled appointment timestamps patched in Medplum (Apr 14–22).
Build #76 batch: UI-1 exit dialog fix; in-call chat removed (Activity only); doctor Communications data layer; 'doctor' role + 'document' AttachmentType; doctor UI panel restructure (Appointments removed, async Medplum chat, read-only report during call).
debugPrint tracing added to finalizeConsultation() for future diagnosis.

## Doctor UI
The doctor UI is a static HTML file served by Caddy.
- Source (edit this): `doctor-ui/index.html` inside this repository
- Deployed location (Caddy serves this): `/home/corb_d/sovereign-factory/doctor-ui/index.html`
- After every edit to `doctor-ui/index.html`, deployment is done manually with:
  `cp /home/corb_d/sovereign-factory/mobile-workspace/TeleMed_K/doctor-ui/index.html /home/corb_d/sovereign-factory/doctor-ui/index.html`
- NEVER edit files directly in `/home/corb_d/sovereign-factory/doctor-ui/` — that folder is deploy-only.
- NEVER create or edit any doctor UI files outside the repository.

**CRITICAL: After every cp deploy, inject credentials (they are empty strings in source for security):**
```python
python3 -c "
content = open('/home/corb_d/sovereign-factory/doctor-ui/index.html').read()
content = content.replace(\"const CLIENT_ID     = '';\", \"const CLIENT_ID     = 'c18b54d9-f511-46db-903e-882b47dc3c63';\")
content = content.replace(\"const CLIENT_SECRET = '';\", \"const CLIENT_SECRET = '7f86f3b5c08e94d711f61a4565c7d577cb303e78a5d57b5d340b74baf8c0b283';\")
content = content.replace(\"const TURN_PASSWORD = '';\", \"const TURN_PASSWORD = 'TeleMed_TURN_2026!';\")
content = content.replace(\"const TURN_USERNAME = '';\", \"const TURN_USERNAME = 'telemed';\")
open('/home/corb_d/sovereign-factory/doctor-ui/index.html', 'w').write(content)
"
```
Basic auth gate at Caddy: **demo / telemed2026** (credentials published in Kaggle writeup demo section).

## Medplum Patient Data (verified 2026-05-15)

| Patient | CNP | Medplum ID | Lang | Condition | Medication |
|---|---|---|---|---|---|
| Maria Ionescu | 2540203150013 | 0c6daf94-7c53-499e-9c46-7d8e77e99b8f | RO | Hipertensiune arterială | Amlodipină 5mg |
| Ion Popescu | 1490815150027 | ba0c27f1-d943-4eda-9789-2a2a77ba3d13 | RO | Diabet zaharat tip 2 | Metformin 1000mg |
| Elena Dumitrescu | 2621105150032 | f4fd5d5d-6553-4b44-9561-06119b0c8f04 | EN | Hypertension | Amlodipine 5mg |
| George Constantin | 1551220150048 | b79e4919-ef7e-4c1a-9274-6869eafbe444 | EN | Type 2 Diabetes | Metformin 1000mg |

Duplicate patients cleaned up — old records (a0e44abc, 510b8c93, 118149bf, 6955bb14) deleted. Only 1 patient per CNP now.

Practitioners: 9 in Medplum with correct names (familyDoctorId = 733e1972-b42d-4bd0-82c7-66db72b2d311 = Dr. Elena Ionescu)

Appointments: Each patient has upcoming + 2 past fulfilled appointments. George's upcoming: 2598af45 (May 16 10:00)

## Session Notes — 2026-05-11 (Fine-Tune Data Pipeline, Steps 5–10)

NO Flutter code modified this session. All work was in tools/finetune/ (Python) and datasets on the GX10.

**Commits this session (chronological):**
- e70371a — Step 5: scaffold tools/finetune/ (pyproject.toml, config.py, .env.example, .gitignore, README.md)
- 060f4b5 — Steps 6–7: pull_romanian.py (500+200 rows) + pull_medical.py (600 rows)
- 3fc891c — Step 8: translate_patient_turns.py; 21 Romanian patient-turn translations (Gemini 2.5-flash, free tier)
- b1590af — Step 9: generate_synthetic.py + seed_examples.py; 121 synthetic dialogues (synth-001..121) across 13 themes
- dcc5b60 — Step 10: merge_train_eval.py; train.jsonl (109) + eval.jsonl (12) + merge_manifest.json

**Fine-tune pipeline state (Steps 1–13b = COMPLETE):**
- tools/finetune/ at repo root, uv-managed Python 3.12 project
- Training data: /home/corb_d/sovereign-factory/datasets/training/train.jsonl (109 dialogues, 688 turns)
- Eval data: /home/corb_d/sovereign-factory/datasets/training/eval.jsonl (12 dialogues, 66 turns)
- Model target: Gemma 4 E4B (same model as LiteRT-LM uses) via Unsloth QLoRA on GX10
- Adapter output: /home/corb_d/sovereign-factory/models/telemed-k-gemma4-e4b-adapter/
- Unsloth aarch64 confirmed working on GX10 — Step 11 completed successfully.
- Steps 11–13b complete. Adapter at huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical.
- Path A3 chosen for deployment (base model + engineered system prompt).

**Step 8 lessons (Gemini quota):**
- Free-tier daily limit: ~100 RPD (requests per day) on Gemini 3 Flash; hit wall at ~80 rows
- Switched to gemini-2.5-flash (~20 RPD limit); completed 21 translations
- 1024 max_output_tokens was too tight for long patient turns; 2048 worked
- 21 translations are variety seeds, NOT direct training data

**Architecture discoveries (affect Flutter before deployment):**
1. JSON schema: engine expects 6-field JSON per turn {response, emergency, confidence, priority, ready_to_finalize, category}
2. Emergency routing: wired but unverified end-to-end (tel:112 launch from EmergencyScreen TBD)
3. Patient-first conversation: AI must NOT greet in Turn 1 — RESOLVED — system prompt updated build #104 commit b2161ea
4. Sentence cap: system prompt says 15 words; training data uses 30-word cap — RESOLVED — 30-word cap in system prompt build #104

**Clinical review: Rareș Bogheanu (project lead, Senior QA architect) + Dr. Adriana Bogheanu + Dr. Mariana Andronescu reviewed all 121 dialogues in real-time (physically present). No deferred review.**

**All steps complete. Fine-tune pipeline closed.**
Steps 1–13b done. See HANDOFF.md for full fine-tune details and deployment decision (Path A3).

## Session Notes — 2026-05-12 (Builds #80–#86)

Build #80: LiteRT-LM 0.10.2 → 0.11.0. ENGINE_INIT_ERROR resolved (libLiteRt.so now bundled in 0.11.0). Green pill confirmed on device.

Build #81: 6 mounted guards across async paths in medical_response_screen.dart. Photo inner try/catch added. C1 still occurring.

Build #82: clear() moved outside setState() in _onSendTap(). Doctor messages excluded from AI context (_buildConversationHistory skips role==doctor). Photo IO dispatcher isolation + file validation. C1 still occurring.

Build #83: FHIR subject reference fixed (CNP identifier → Patient/{medplumId} direct reference). valueString fixed (lastAiText parameter). FHIR write confirmed — entries appear in Medical Dossier. Attempted C1 fix via ref.watch removal introduced new bug (ref.watch in async methods).

Build #85: ref.watch/ref.read split corrected (local lang variable in build-path only; ref.read getter in async). Photo crash fixed — async deferred pattern, 60s timeout, native call never cancelled. Photo no longer crashes — returns Romanian fallback message.

Build #86: C1 root cause confirmed — unawaited stopAndRelease() in dispose() completes after super.dispose() on dead ref. Fix: capture audioService before dispose(). Also: _showImagePreview() missing mounted check (deactivated ancestor). RESOLVED — C1 confirmed debug-only in release build #102. Not user-facing.

Confirmed working as of build #85:
- E4B voice inference: working, AI responds correctly
- E4B photo inference: no crash, fallback, thumbnail tappable
- FHIR write: entries in Medical Dossier with correct content
- Photo full-screen: tappable and viewable

## Session Notes — 2026-05-13 (Builds #87–#102)

Build #89: diagnostic — _loadDoctorCommunications disabled to isolate C1 race (C1 persisted — race ruled out).

Build #90/#91: postFrameCallback deferral for _onTextChanged; audio/photo patient message added before inference call; doctor comms re-enabled. C1 persisted in debug.

Build #95: release APK added to CI workflow (assembleRelease + upload telemed-release-apk artifact).

Build #96: Symptom Analysis card changed to show lastPatientMessage (patient's complaint) instead of lastAiResponse (AI's reply). Broken warmup introduced (crashed post-download) — removed in #97/#98.

Build #99: EN triage system prompt restored (was removed in fine-tune commit b2161ea — triage prompt became Romanian-only). Release DNS fixed (network_security_config domain-config). Patient message deduplication attempted in Kotlin (caused crash).

Builds #100–#101: inference pipeline refactored to split systemPrompt from conversation context. Still crashing — root cause not yet found.

Build #102: ProGuard keep rules added for LiteRT-LM JNI callbacks. RELEASE CONFIRMED WORKING. Text/voice/photo all return AI responses without crash.

Key diagnosis: crash was R8 minification renaming JniMessageCallback.onMessage()/onDone() — native JNI could not find the methods by reflection in release build. Debug never showed this because ProGuard is disabled in debug.

Confirmed working in release build #102:
- Text inference: AI responds in English correctly
- Voice inference: AI responds correctly
- Photo inference: fallback message returned, no crash
- Model download: works in release
- FHIR write / Medical Dossier: confirmed working

## Session Notes — 2026-05-14 (Builds #103–#104)

Build #103: patient-AI interaction fixes — initialAiResponse parameter, audio/photo conversation context to Kotlin, triage card removed, AAC path stored for replay, ready_to_finalize highlights Finalize button blue, raw file paths → emoji labels.

Build #104: full audit cleanup across 10 rounds — AppStrings coverage complete (all UI strings localized EN/RO), error handling gaps filled (audio file-existence check, camera/mic/inference SnackBars), security hardened (credentials via dart-define), dead code removed, TeleMed Hearth rename complete, FhirExtensionUtils shared helper, MedplumRepository.base centralized, withOpacity CI compatibility, ProGuard JNI keep rules confirmed working, system prompt 3-question limit + rolling summary, session isolation _doctorPresent reset, model size corrected to ~3.5GB, diagnostic dialog removed.

Audit state after #104: 0 critical, 0 high, 0 medium, 0 low. Codebase ready for public repo.

## Session Notes — 2026-05-14 (Builds #105–#107)

Build #105: AI error pill on dashboard — when initializeModel() fails, pill shows "AI error — tap for info" in amber; tap opens AlertDialog with SelectableText of the full error string. initErrorNotifier ValueNotifier added for reactive updates. Also: audio file-existence check before playback with user-facing SnackBar.

Build #106: Data fixes and UX improvements —
- seedMockData updated to 4 patients matching Medplum (Maria/Ion/Sarah/George; 5th patient removed); gender field added; per-patient MedicationRequest resources; dangling Patient/mock-patient-1 reference fixed.
- Appointment status chips added for all statuses (fulfilled/cancelled/noshow/confirmed).
- Past appointments (startTime < now) no longer show "Enter consultation" button.
- Doctor Communications 7-day filter to prevent stale messages bleeding into new sessions.
- lastImagePath added to MedicalSessionState — photo from home-screen triage now tappable in chat.
- Finalize button always blue when active; glows when ready_to_finalize; grey only when processing.

Build #107: Chat UX improvements —
- Conversation history capped to last 10 messages (prevents unbounded context growth).
- Summary card above message list shows last AI response — updates after each turn.
- PDF/doc/docx file types added to file picker; OCR fallback uses chat.pdf_attached key.
- FHIR history context limited to last 3 Observations (speeds up inference).

## Session Notes — 2026-05-15 (Builds #108–#111)

Build #108: Engine Kotlin/Dart state sync (isEngineReady MethodChannel added to LiteRtLmChannel.kt; Dart checks before every inference and auto-reinits on divergence); auto language on login (_patientLanguage map in PatientAuthNotifier + HomeScreen initState sync); join window restored to -60/+120min; peer left overlay fully opaque black.

Build #109: 5-question limit updated; CLASSIFY instruction conflict removed from buildConversationContext(); turn counter added to conversation history header; CNP submit button permanent disable (OTP button still had bug); AAC path fix for audio replay (updateAudioPath()); home photo permanent path copy (updateImagePath()); activity panel snap:false; Doctor UI: clinical summary from obs.note last [AI] line, back-to-appointments button, expand conversation toggle; evaluateAudio() customPrompt removed (in-chat voice fix).

Build #110: Dialogue numbering (#N oldest=1) in history_screen.dart + dialog_detail_sheet.dart; summary card replaced with static info card (dismissible); finalize button stuck fix (_isFinalizing reset on success); AI clinical summary generation at finalization (combined prompt, fallback detection); category stored from last AI result; Clinical Summary / Rezumat Clinic label in Dossier; evaluateMedia customPrompt removed; OTP button permanent disable fix in login_verification_screen.dart; activity panel snap:false confirmed.

DEVICE-TESTED BUILD #110:
- All 4 patients login correctly with correct language, dashboard, conditions, medications ✓
- Maria (RO): voice triage, finalize, see dialogue in Dossier ✓
- Sarah (EN): text triage, photo taken, AI responds correctly ✓
- Video call Pixel 9 Pro (patient) + laptop Brave (doctor): stable 5+ minutes ✓
- Doctor UI: see appointments, view report, mark reviewed, expand conversation ✓
- Medical Dossier: dialogue numbering, Clinical Summary label, continue conversation ✓

Build #111 (CI building): Clinical summary combined prompt fix (no customPrompt, history embedded in text); photo thumbnail existsSync removed (direct try/catch copy with fallback); photo AI suggestion conditional (only when no photo sent); OTP verification button permanent disable correct; AppBar title reverted to generic (patient name removed); snap:false confirmed. Credential injection reminder added to CLAUDE.md Doctor UI section.

## Session Notes — 2026-05-15 (Builds #112–#113)

### Build #112 device-test results (release APK on Pixel 9 Pro)
PASS: Fix #1 (state corruption recovery), Fix #2 (EN system prompt), Fix #3 (EN safety clause), Fix #4 (voice-in-chat history), Fix #6 (photo resize), Fix #10 (Programări back-nav), tab navigation (Medic / Specialiști).
FAIL: Fix #5 (Finalize spinner hangs indefinitely — regression), Fix #7 (5-question limit still ignored by model), Fix #8/#8b (activity panel still won't dismiss), Fix #9 (peer-left frozen frame persists).

New issues surfaced during #112:
- Ion and Elena had empty Recent Activity (no Observations in Medplum) → seeded 2 Obs + 1 Appointment each via curl
- "Recent Health Status" rendered EN in RO session (hardcoded in DateFormatter)
- New appointment didn't appear in list until app restart (_hasLoaded guard blocked re-fetch)
- Doctor UI Patient Report showed AI clarifying question as Clinical Summary (note[0].text field-read mismatch)
- Doctor UI transcript showed raw Android file paths ([Voice:/data/user/...])
- Doctor UI video aspect ratio wrong (objectFit:cover instead of contain)
- Doctor UI Unmute button partially cut off at left edge (cosmetic, accepted for demo)
- Home screen greeting mismatched loading state ("Good day, Sarah!")

Medplum cleanup performed (curl-based, no code commits):
- Sarah Dumitrescu renamed to Elena Dumitrescu (Patient f4fd5d5d-..., CNP 2621105150032)
- 7 orphan Appointments deleted (referencing deleted patients a0e44abc + 510b8c93)
- 3 stale booked Appointments for Ion cancelled (May 14–15)
- Ion: seeded 2 Observations (May 9 diabetes, April 18 neuropathy) + 1 fulfilled Appointment (May 9)
- Elena: seeded 2 Observations (May 8 arthritis, April 22 wrist pain) + 1 fulfilled Appointment (May 8)
- Default Client credentials confirmed: id=c18b54d9-f511-46db-903e-882b47dc3c63; old credentials (d5d39070-... / TeleMed_K_Client_Secret_2026!) returned invalid_client

Architectural decisions resolved:
- Path A3 final: litert-torch hf_export.export() (commit 1572220e9b) supports Gemma 4 text-only, but vision encoder LoRA merge unsupported; post-hackathon
- Patient ID Case 1 confirmed: login uses local FHIR SDK; Ion's #112 Observation 67b2925a landed against ba0c27f1, confirming all writes use correct Medplum ID; Medplum-search-by-CNP at login is post-hackathon
- No fine-tune deployment: adapter artifact published on HuggingFace; base + system prompt + sampling (temp=0.3, top_p=0.9, top_k=40) is shipped config

### Build #113 fixes (commit 95eda78)
- Fix #11: 30s timeout on clinical summary evaluateText; JSONL diagnostic log; _screenFinalized reset on error
- Fix #12: Clinical summary surfaced in Doctor UI — [AI] line appended to note[0].text; Doctor UI filter(l => l.startsWith('[AI]')).last picks it up
- Fix #13: Attachment path leak — voice/photo FHIR transcript uses localized labels (AppStrings chat.attachment_voice_label / chat.attachment_photo_label) instead of raw file paths
- Fix #14: Activity panel dismiss — same SurfaceView removal pattern as Fix #9: _chatOpen==true → _buildRemoteVideo() returns black Container
- Fix #15: Peer-left detection via onConnectionState (Disconnected/Failed/Closed) + onIceConnectionState (Disconnected/Failed) + signaling 'leave'; RTCVideoView objectFit → Contain; peer-left nulls srcObject
- Fix #16: Appointment list refresh — reset _hasLoaded = false before _loadAppointments() in save-success branch; ref.invalidate(appointmentsProvider) was already present but _hasLoaded guard blocked re-fetch
- Fix #17: "Recent Health Status" — DateFormatter.format() fallback param added; history_screen.dart passes AppStrings.of(lang, 'history.recent_date')
- Fix #18: Loading-state headline — sessionState==processing swaps "Good day, {name}!" / "How do you feel today?" to "One moment, {name}…" / "Looking at what you shared…" (AppStrings keys dashboard.loading_personal / dashboard.loading_status)
- Fix #19: Finalize button onPressed guard adds || _screenFinalized so button stays visually disabled throughout entire _onFinalize() execution (was only _isFinalizing || _isProcessing)
- Fix #20: Deduped _buildConversationHistory() + _buildTruncatedConversationHistory(int) → unified _buildConversationHistory(int maxMessages); added per-modality cap: max 2 patient-voice + 2 patient-photo in AI context; older turns rewritten to [information accounted] / [informație adăugată la context] in context copy only (UI unchanged); AppStrings key chat.information_accounted_label

Demo-day morning pending:
- Patient ID Case 1 re-verify after first Ion login on #113 APK
- Seed Ion's 10:00 demo Appointment (curl, ~30 seconds) — NOT YET CREATED
- Full #113 device regression against demo-flow script

## Post-Hackathon Roadmap
- Gemma real-time call summarization (WebRTC audio → STT → Gemma → FHIR Observation)
- Patient PDF send to doctor via DocumentReference
- Doctor Communications real-time polling
- WiFi-triggered background sync
- Fine-tuned adapter deployment via litert-torch hf_export.export() when vision encoder support lands
- Login flow: replace local FHIR SDK seed with Medplum CNP search
- Emergency keyword safety net redesign (EMERGENCY_KEYWORDS_RO has 12 terms, too narrow)
- Voice/photo context bridging: raise cap from 4, proper FHIR-block trimming
- Running session summary architecture (investigated, deferred)
- Stale Default Client secret rotation (c18b54d9-... credential flagged)
- Doctor UI controls layout polish (Unmute cut off)
- JSONL debug log rotation (currently unbounded)

## Claude Code Custom Commands
Location: .claude/commands/
  audit.md — full codebase audit (trigger with /audit)
