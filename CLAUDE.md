# TeleMed_K — Claude Code Session Context

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
- Mock patient DB: 5 Romanian patients seeded in FhirEngineChannel.kt
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

## Open Issues (carry to next session)

### P0 — RESOLVED
- C1 (_dependents.isEmpty + deactivated ancestor): debug-only Flutter assertion. Release build confirmed working (build #102). Not user-facing. Multiple root causes addressed across builds #81–#90.
- Release APK crash on inference: RESOLVED build #102 — ProGuard keep rules for LiteRT-LM JNI callbacks (R8 was renaming onMessage/onDone, causing NoSuchMethodError).
- Release APK model download DNS failure: RESOLVED build #99 — network_security_config.xml domain-config for duckdns.org.

### P0 — NONE. All critical and high items resolved.

### P1 — RESOLVED (builds #103–#107)
- First photo from home screen not tappable in chat — RESOLVED #103 (initialImagePath wired)
- Finalize button always grey until AI says ready_to_finalize — RESOLVED (always blue when active)
- Appointment status labels missing (fulfilled/cancelled/noshow) — RESOLVED (chips added)
- Doctor Communications bleeding into new sessions (old messages shown) — RESOLVED (7-day filter)
- Raw file paths in dialogue replay ([Voice:/data/...]) — RESOLVED #103

### P1 — STILL OPEN
- Video call quality — needs two-device test (TURN fix applied 2026-05-08, unconfirmed)
- iPad Safari: chat stripe tap unresponsive, doctor list empty
- Emergency routing: EmergencyScreen → tel:112 — device test pending
- Mic not released after video call ends — needs device retest
- Activity panel (VideoConsultationScreen): tap-outside dismiss + title — needs device retest
- "Your medical assistant" AppBar title in chat — consider renaming to doctor name or clinic name

### Post-hackathon
- T4: Triage back button background not white
- D3: Could not load photo error on profile photo upload
- Patient PDF send: plain text notification only
- Doctor Communications polling: not real-time

## Current State
See TELEMED_CONTEXT.md for full verified/awaiting-test/broken breakdown.
Last updated: 2026-05-14
Latest build: #107 (CI building).
Last device-tested: #105 release — AI confirmed working. Build #107 awaiting CI + device test.
4 patients created in Medplum (Maria/Ion/Sarah/George) with conditions, medications, appointments.
All 9 practitioners named in Medplum.

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

## Session Notes — 2026-05-11 (Fine-Tune Data Pipeline, Steps 5–10)

NO Flutter code modified this session. All work was in tools/finetune/ (Python) and datasets on the GX10.

**Commits this session (chronological):**
- e70371a — Step 5: scaffold tools/finetune/ (pyproject.toml, config.py, .env.example, .gitignore, README.md)
- 060f4b5 — Steps 6–7: pull_romanian.py (500+200 rows) + pull_medical.py (600 rows)
- 3fc891c — Step 8: translate_patient_turns.py; 21 Romanian patient-turn translations (Gemini 2.5-flash, free tier)
- b1590af — Step 9: generate_synthetic.py + seed_examples.py; 121 synthetic dialogues (synth-001..121) across 13 themes
- dcc5b60 — Step 10: merge_train_eval.py; train.jsonl (109) + eval.jsonl (12) + merge_manifest.json

**Fine-tune pipeline state (Step 11 = Unsloth training, NEXT):**
- tools/finetune/ at repo root, uv-managed Python 3.12 project
- Training data: /home/corb_d/sovereign-factory/datasets/training/train.jsonl (109 dialogues, 688 turns)
- Eval data: /home/corb_d/sovereign-factory/datasets/training/eval.jsonl (12 dialogues, 66 turns)
- Model target: Gemma 4 E4B (same model as LiteRT-LM uses) via Unsloth QLoRA on GX10
- Adapter output target: /home/corb_d/sovereign-factory/models/telemed-k-gemma4-e4b-adapter/
- RISK: Unsloth aarch64 install is UNTESTED — first major blocker for Step 11

**Step 8 lessons (Gemini quota):**
- Free-tier daily limit: ~100 RPD (requests per day) on Gemini 3 Flash; hit wall at ~80 rows
- Switched to gemini-2.5-flash (~20 RPD limit); completed 21 translations
- 1024 max_output_tokens was too tight for long patient turns; 2048 worked
- 21 translations are variety seeds, NOT direct training data

**Architecture discoveries (affect Flutter before deployment):**
1. JSON schema: engine expects 6-field JSON per turn {response, emergency, confidence, priority, ready_to_finalize, category}
2. Emergency routing: wired but unverified end-to-end (tel:112 launch from EmergencyScreen TBD)
3. Patient-first conversation: AI must NOT greet in Turn 1 — system prompt needs updating
4. Sentence cap: system prompt says 15 words; training data uses 30-word cap — must align

**Clinical review: Rareș Bogheanu (project lead, Senior QA architect) + Dr. Adriana Bogheanu + Dr. Mariana Andronescu reviewed all 121 dialogues in real-time (physically present). No deferred review.**

**Next session must:**
1. Verify Unsloth installs on aarch64 (Step 11 first risk)
2. Run QLoRA fine-tune on train.jsonl
3. Evaluate on eval.jsonl (12 dialogues, manual read)
4. Update system prompt in ai_engine_service.dart (patient-first + 30-word cap)
5. Verify emergency routing: EmergencyScreen → tel:112 → confirm url_launcher fires
6. Resume Flutter P0 issues (E4B ENGINE_INIT_ERROR, C1 regression) — NOT touched this session

## Session Notes — 2026-05-12 (Builds #80–#86)

Build #80: LiteRT-LM 0.10.2 → 0.11.0. ENGINE_INIT_ERROR resolved (libLiteRt.so now bundled in 0.11.0). Green pill confirmed on device.

Build #81: 6 mounted guards across async paths in medical_response_screen.dart. Photo inner try/catch added. C1 still occurring.

Build #82: clear() moved outside setState() in _onSendTap(). Doctor messages excluded from AI context (_buildConversationHistory skips role==doctor). Photo IO dispatcher isolation + file validation. C1 still occurring.

Build #83: FHIR subject reference fixed (CNP identifier → Patient/{medplumId} direct reference). valueString fixed (lastAiText parameter). FHIR write confirmed — entries appear in Medical Dossier. Attempted C1 fix via ref.watch removal introduced new bug (ref.watch in async methods).

Build #85: ref.watch/ref.read split corrected (local lang variable in build-path only; ref.read getter in async). Photo crash fixed — async deferred pattern, 60s timeout, native call never cancelled. Photo no longer crashes — returns Romanian fallback message.

Build #86: C1 root cause confirmed — unawaited stopAndRelease() in dispose() completes after super.dispose() on dead ref. Fix: capture audioService before dispose(). Also: _showImagePreview() missing mounted check (deactivated ancestor). AWAITING DEVICE CONFIRMATION.

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

## Session Notes — 2026-05-11 (Fine-Tune Steps 5–10)

NO Flutter code modified. All work in tools/finetune/.
Commits: e70371a, 060f4b5, 3fc891c, b1590af, dcc5b60
Training data: train.jsonl (109 dialogues) + eval.jsonl (12)
Dr. Bogheanu reviewed all 121 synthetic dialogues in real-time.
Architecture discoveries affect Flutter — see P1 Open Issues above.
Next: Step 11 Unsloth QLoRA fine-tune on GX10.

## Post-Hackathon Roadmap
- Gemma real-time call summarization (WebRTC audio → STT → Gemma → FHIR Observation)
- Patient PDF send to doctor via DocumentReference
- Doctor Communications real-time polling
- WiFi-triggered background sync

## Claude Code Custom Commands
Location: .claude/commands/
  audit.md — full codebase audit (trigger with /audit)
