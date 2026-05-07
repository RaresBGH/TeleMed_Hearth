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
- LiteRT-LM 0.10.2 (Gemma 4 E4B on-device inference)
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
- Doctor UI sliding panel — 3 states (Appointments / Patient Report / In-Call); Mark reviewed → PATCH reviewed-by; Finalize → PATCH status:final; responsive
- WaitingRoomScreen STATE B: "See my recent activity" button → bottom sheet with last 5 Observations (date, category chip, excerpt)
- VideoConsultationScreen: Activity tab in DraggableScrollableSheet alongside Chat tab; loaded on initState, read-only
- FHIR PATCH: always use application/json-patch+json (RFC 6902 array) — Medplum 5.1.10 rejects merge-patch with 400
- finalizeConsultation _finalized: reset as first line of reset() before stopAndRelease() — prevents audio exceptions blocking future FHIR writes
- patientHistoryProvider: invalidated inside notifier after successful FHIR write via try { ref.invalidate(...) } catch (_) {}
- Bottom nav: localised via languageProvider + AppStrings (nav.home / nav.dossier / nav.doctor), reactive to EN/RO toggle
- In-call chat: bidirectional via WebSocket — patient sends {type:'chat',sender:'patient',text} or {imageData,filename}; doctor sends {type:'chat',sender:'doctor',text} or {documentReferenceId,filename}; both sides wired
- AppointmentsScreen: showBookingButton=false by default (read-only from dashboard); screenTitle parameter for contextual title; family doctor scoped to familyDoctorId explicitly
- Doctor profile: specialty shown as AppBar top label; entitlement string (from Practitioners.*entitlement) shown below name
- Medplum-first reads: getMostRecentEncounter uses fulfilled Appointments; getMostRecentMedicationRequest and getPatientHistory (Conditions + Observations) all online-first with local fallback

## Open Issues (carry to next session)
- T3: AI context reset mid-conversation — "Hello. What brings you..." reappears between turns
- T4: Triage back button background not white
- D3: "Could not load photo" error on profile photo upload
- Patient PDF send: sends plain text notification only — no DocumentReference ID available from saveCommunication return value; post-hackathon fix
- P1-5/6/7: Mic release, end-call keyboard, mute chip — still pending two-device video call test

## Current State
See TELEMED_CONTEXT.md for full verified/awaiting-test/broken breakdown.
Last updated: 2026-05-07
Latest build: #75 — in progress (not yet pushed). Last pushed build: #73. Last device-tested build: #74.
GitHub Actions secrets MEDPLUM_CLIENT_ID and MEDPLUM_CLIENT_SECRET are set correctly.
Medplum sync confirmed working — appointments, observations, and communications reach https://telemed-medplum.duckdns.org/fhir/R4.
Medplum Binary storage confirmed working: file:///var/medplum/storage.
WebRTC two-device video call confirmed working end-to-end (patient Pixel 9 Pro + doctor Brave browser).
On-device AI inference confirmed working — Gemma 4 E4B responds to text and voice in correct language.
Doctor UI at https://telemed-doctor.duckdns.org confirmed working — shows today's appointments, joins video call, bidirectional chat working.
Signaling server: telemed-signaling.service confirmed running under systemd, auto-restarts on reboot.
medplum_token alias added to ~/.bashrc for Terminal 2 token refresh.

## ADB Commands
adb -s 4C041FDAP006Z1 logcat -d | grep -E "LiteRtLm|flutter|com.example.telemed_k" | tail -40
adb -s 4C041FDAP006Z1 shell pm clear com.example.telemed_k && adb -s 4C041FDAP006Z1 uninstall com.example.telemed_k

## Code Quality
Audit round 4 completed 2026-05-06. All findings resolved.
Build #75 batch: 25+ fixes across appointments, dashboard, doctor UI, video call, chat, PDF/image transfer. 0 analyze errors.
Additional fixes: join window corrected (-60min/+120min); dashboard appointment filter broadened (booked+confirmed, within 2h past); 'Family Doctor' → 'Family Medicine'; doctor UI isCallActive guard, frozen video clear on peer exit, redundant PANEL tab removed; fulfilled appointment timestamps patched in Medplum (Apr 14–22).
debugPrint tracing added to finalizeConsultation() for future diagnosis.

## Doctor UI
The doctor UI is a static HTML file served by Caddy.
- Source (edit this): `doctor-ui/index.html` inside this repository
- Deployed location (Caddy serves this): `/home/corb_d/sovereign-factory/doctor-ui/index.html`
- After every edit to `doctor-ui/index.html`, deployment is done manually with:
  `cp /home/corb_d/sovereign-factory/mobile-workspace/TeleMed_K/doctor-ui/index.html /home/corb_d/sovereign-factory/doctor-ui/index.html`
- NEVER edit files directly in `/home/corb_d/sovereign-factory/doctor-ui/` — that folder is deploy-only.
- NEVER create or edit any doctor UI files outside the repository.

## Claude Code Custom Commands
Location: .claude/commands/
  audit.md — full codebase audit (trigger with /audit)
