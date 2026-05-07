# TeleMed_K — Handoff Summary
**Date:** 2026-05-05  
**Deadline:** May 18, 2026 — **12 days remaining**  
**Repo:** https://github.com/RaresBGH/TeleMed_K (PRIVATE — must go public before deadline)  
**Latest commit:** build #75 — in progress (not yet pushed). Last pushed: build #73. Last device-tested: build #74.

---

## Context

Flutter telemedicine app for rural Romania. Dr. Rareș Bogheanu's clinic in Brănești, Dâmbovița.  
Target users: elderly patients (70s–80s) with low tech literacy; NGO provides devices.  
Competition: Kaggle Gemma 4 Good Hackathon.  
Primary AI: Gemma 4 E4B (3.5GB model, LiteRT-LM 0.10.2) — runs fully on-device.  
FHIR backend: Google Android FHIR SDK (local encrypted SQLite) + Medplum 5.1.10 (self-hosted, dual-write).

---

## Mandatory Rules (from CLAUDE.md — enforce these always)

1. **VERIFY before acting** — read every file before editing it
2. **ONE step at a time** — never assume a previous step succeeded
3. **FINISH MESSAGE required** on every task
4. **Before every commit** — run `flutter analyze --no-pub 2>&1 | grep -E 'error|warning' | head -20` — fix all errors; warnings acceptable
5. **Never guess** — ask if unsure
6. **No autonomous git operations** — user controls all git commits/pushes
7. **No localhost for inter-container calls** — Docker uses service names
8. **No host-level commands for containerized apps** — use `docker exec`

---

## Hardware & Build Environment

| Item | Value |
|---|---|
| Dev machine | ASUS GX10 (aarch64, ARM64, Ubuntu 24.04, 128GB RAM, NVIDIA GB10) |
| Flutter | 3.44.0 master channel at `/snap/bin/flutter` (local dev) |
| CI Flutter | 3.32.0 stable (GitHub Actions ubuntu-latest x86_64) |
| Test device | Google Pixel 9 Pro — serial `4C041FDAP006Z1` |
| ADB | USB (unreliable); install via GitHub Actions APK artifact |
| Java | 17 (compileSdk=36, minSdk=28) |
| **AAPT2 note** | AAPT2 binary is x86_64 — local `./gradlew assembleDebug` fails on GX10 ARM64; CI is the build path |

---

## Verified Working Features (confirmed on-device)

- CNP + OTP auth (official Romanian CNP spec; demo OTP = last 6 CNP digits; 3-attempt lockout)
- Phone validation (07XXXXXXXX realtime)
- Model download (OkHttp foreground service, HTTPS from telemed-b.duckdns.org, resume on reconnect)
- Model download auto-advance to home on success
- Chat screen with Gemma 4 (raw JSON stripped, follow-up inference correct)
- Patient/AI bubble styling distinct
- Single FHIR Observation per consultation (no duplicates)
- Dosar Medical detail tap + replay
- Resume from history (loads prior messages into MedicalResponseScreen)
- Back button exit dialog (PopScope, hardware back handled)
- Emergency 112 routing
- Session guard (auth/download routes protected)
- LiteRT-LM E4B dual-path model lookup
- Audio recording (WAV 16kHz, AAC transcode)
- Camera capture (JPEG 85)
- Legal screens (WebView, EN/RO, H4)
- Lexend font, dark theme (follows system)
- H1: Language toggle on login
- H2: Valid Romanian CNPs seeded (county 15, NNN 001–005; OTPs confirmed)
- Language toggle EN/RO confirmed on device (build #64) — defaults correctly to EN
- Appointment screen: past dates blocked; future slots filtered for today; 30 slots (09:00–23:30)
- Appointment Medplum sync confirmed — new bookings appear in doctor UI within seconds
- Doctor UI (telemed-doctor.duckdns.org) — Medplum auth working; today's appointments listed; date range query fixed
- WebRTC two-device video call confirmed end-to-end — patient Pixel 9 Pro + doctor Brave browser
- Waiting room mute/video buttons apply to actual media tracks
- In-call chat: no keyboard overflow; end call works (single tap when keyboard closed)
- Triage chat: voice bubble shows play button; photo bubble shows tappable thumbnail
- AI conversation context maintained across turns (history passed as customPrompt)
- On-device AI inference confirmed working — Gemma 4 E4B responds in correct language
- GitHub Actions secrets MEDPLUM_CLIENT_ID and MEDPLUM_CLIENT_SECRET confirmed set and working
- Doctor UI sliding panel deployed at https://telemed-doctor.duckdns.org: 3-state panel (Appointments / Patient Report / In-Call); patient triage report with chronic conditions, unreviewed dialogues, Mark reviewed → PATCH reviewed-by extension, Finalize → PATCH status:final; In-Call panel: Chat tab + Activity tab (last 5 Observations); responsive 320px desktop / 280px tablet overlay / full-width mobile; join window -60min to +120min
- All practitioner names replaced with approved mock names throughout app and Medplum
- All 9 specialist Practitioner resources created in Medplum with real UUIDs
- Appointment join grace window: joinable from 60 minutes before to 120 minutes after scheduled time
- Doctor UI deployment: source at doctor-ui/index.html in repo; Caddy serves from /home/corb_d/sovereign-factory/doctor-ui/index.html; deploy with cp command documented in CLAUDE.md
- WaitingRoomScreen STATE B: "See my recent activity" button → bottom sheet with last 5 Observation summaries (date, category chip, AI summary excerpt)
- VideoConsultationScreen: Activity tab alongside Chat tab in DraggableScrollableSheet; last 5 Observations loaded on initState; read-only cards with category chip
- MedicalSessionState.lastPractitionerRef: propagated through all 5 state copy sites (clearPreseed, clearPatientMessage, prepareResume, setDoctorContext, _handleResult); written as reviewed-by-target FHIR extension on finalizeConsultation

---

## Built — Awaiting Device Test

The following are code-complete but not yet confirmed on Pixel 9 Pro:

| Feature | Key risk |
|---|---|
| Mock patient DB (valid CNPs) | First-launch seed timing |
| Returning vs new user detection | FHIR query on seed data |
| Profile completion (new user flow) | FHIR Patient write |
| Dashboard (FHIR condition/medication/appointment) | FHIR read from local SDK |
| H3: ML Kit OCR + voice in Ajutor | ML Kit 15s timeout; first-launch warm-up |
| H4: Legal screens WebView | WebView rendering on-device |
| H5: Back button + Trimite mesaj routing | Navigator.push/pop stack |
| H6: Consent screen layout | Checkbox touch target |
| H7: In-call chat panel | DraggableScrollableSheet keyboard |
| H8: Voice confirm dialog | Dialog dismiss path |
| H9: Document attachment + audio replay | FilePicker + just_audio |
| H11: Medplum sync | Requires GitHub Actions secrets (see below) |
| H12: WebRTC signaling | Requires both peers on same signaling room |
| H13: Doctor browser UI | Requires Medplum token + appointment data |
| AI engine rewrite (system prompt, session isolation, streaming shim) | First inference latency |

---

## Outstanding Bugs — Priority Order

### P1 — ALL FIXED. No open P1 items.

### P2 — FIXED in build #69 batch:
- Appointments join window: -60min / +120min (matches doctor UI)
- "Request new appointment" button fixed at bottom of screen, outside scrollable area
- Dashboard "Available now" green chip removed from health card
- Dashboard "Available now" pill removed from DoctorProfileScreen
- patientAvatarProvider watch isolated in Consumer widget in _buildHeader() — fixes intermittent _dependents.isEmpty crash
- Doctor message flow: initialPrompt set to null — no AI inference triggered on entry, no pre-populated bubble
- Bottom nav labels localised via AppStrings + languageProvider: nav.home / nav.dossier / nav.doctor
- DialogDetailSheet: "Continue conversation" hidden for status=final observations; replaced with locked indicator
- history_screen _getFallbackText: hardcoded Romanian strings replaced with AppStrings keys
- history_screen Semantics label localised via AppStrings
- finalizeConsultation _finalized reset bug fixed: _finalized=false moved to first line of reset() so stopAndRelease() exceptions no longer permanently block FHIR writes in subsequent sessions
- ref.invalidate(patientHistoryProvider) added after successful FHIR write in finalizeConsultation()
- debugPrint tracing added to finalizeConsultation()
- Medplum conditions patched to English via REST: Ion Popescu → "Type 2 Diabetes", Maria Ionescu → "Arterial Hypertension"

### FIXED in build #75 batch:
- T-NEW-4a/4b: Red screen on text send and exit — mounted guard on appNavigationProvider listener
- C1: _dependents.isEmpty — KeyedSubtree + mounted guard (fully resolved)
- BUG-A/B/C/D: Practitioner name resolution — full lookup map all 9 practitioners
- BUG-E: WaitingRoomScreen specialty display — doctorSpecialty parameter added
- BUG-F/G: FHIR local fallback + Kotlin double-prefix — stripped in both layers
- A-NEW-1: Appointment cards missing specialty — extracted from description, shown as subtitle
- AP-1: "Request new appointment" always visible — showBookingButton=false by default
- AP-2: Calendar title not contextual — screenTitle parameter
- AP-4: Last consultation shows Unknown — Medplum fulfilled appointments path
- AP-5: Active prescription no context — "Prescribed for: {conditionName}" subtitle
- AP-6: "Data recenta" Romanian title — "Recent Health Status"
- Dashboard medication / conditions missing from Medplum — Medplum-first paths added
- Doctor profile top label and entitlement — specialty as AppBar title, entitlement below name
- Family doctor appointment scoping — familyDoctorId passed explicitly
- VC-1/2/3/4: In-call panel, Patient Report from call, chat cleared, video quality — all fixed
- Flutter in-call chat: both directions wired (incoming + outgoing over WebSocket)
- Patient image attachments: base64 sent over WebSocket in _attachCallFile
- Doctor PDF send: Binary + DocumentReference + WebSocket notify
- Doctor receives patient images: inline display in doctor UI chat
- Join window corrected: -60min before to +120min after start (was reversed: -2h/+1h)
- Dashboard appointment filter: accepts 'booked' OR 'confirmed', includes appointments within 2h past start
- 'Family Doctor' EN string corrected to 'Family Medicine'
- Doctor UI: isCallActive guard prevents panel reverting to Appointments during active call
- Doctor UI: frozen remote video frame cleared (srcObject=null) on peer exit
- Doctor UI: redundant blue PANEL tab removed from DOM
- Fulfilled appointment timestamps patched in Medplum to distinct dates/times (Apr 14–22)

### OPEN BUGS — carry forward:
- T3: AI resets to "Hello. What brings you to the doctor today?" mid-conversation
- T4: Triage back button not white background
- D3: "Could not load photo" error on profile photo upload
- Patient PDF send: plain text notification only — no DocumentReference ID from saveCommunication; post-hackathon fix
- P1-5/6/7: Mic release, end-call keyboard, mute chip — pending two-device video call test

### POST-HACKATHON TRACKER:
- Duplicate Observation schema (finalizeConsultation vs _saveCallSummary) — refactor to shared factory
- WiFi-triggered background sync via ConnectivityListener
- main.dart and auth_provider.dart direct FhirRepository() kept intentionally (startup / circular import)

---

## Infrastructure State

### GX10 (ARM64 sovereign AI server — 192.168.0.144 ethernet / 192.168.0.101 WiFi)

| Service | Status | URL |
|---|---|---|
| caddy-telemed.service | Running | Serves telemed-b, telemed-doctor, telemed-signal on 443 |
| telemed-signaling (Node.js) | Running (PID in session) | ws://0.0.0.0:8765; wss://telemed-signal.duckdns.org |
| Medplum 5.1.10 | Running | https://telemed-medplum.duckdns.org/fhir/R4 |
| Gemma model server (Caddy) | Running | https://telemed-b.duckdns.org/gemma-4-E4B-it.litertlm — served from GCP VM /home/rares_bogheanu/gemma-4-E4B-it.litertlm |
| WireGuard | Running | GX10 peer 10.0.0.2 ↔ GCP VM 10.0.0.1 |

**telemed-signaling.service** is running under systemd and auto-restarts on reboot. No manual restart needed.

### GCP VM (telemed-proxy, e2-micro, Frankfurt — 34.185.191.34)

- Caddy routes all `telemed-*.duckdns.org` domains via WireGuard to GX10
- **No SSH key from GX10** → GCP changes must be made from the operator's local laptop
- coturn (TURN server) NOT yet installed on GCP VM — pending manual SSH install

### Medplum

- HTTP 200 confirmed on `/fhir/R4/metadata`
- 5 patients + 5 conditions + 2 practitioners seeded
- Client credentials: ID `c18b54d9-f511-46db-903e-882b47dc3c63` / Secret `7f86f3b5c08e94d711f61a4565c7d577cb303e78a5d57b5d340b74baf8c0b283`
- **In-app credentials are dart-define** — not hardcoded in source (R1 fix)
- GitHub Actions CI builds with empty credentials unless secrets are added

**Rich test data (Ion Popescu, Maria Ionescu — patched to English):**

Ion Popescu (Patient/118149bf-26e0-46e1-87de-7149e8066284)
  CNP: 1490815150027 | OTP: 150027
  Condition: Type 2 Diabetes (ID: 1b02b21e-e6ae-4723-961b-cecd4cb2085e)
  Medications: 2 active
  Appointments: 3 fulfilled (April 22) + booked
  Observations: 6 (2 exam + 4 survey) — all categories correct

Maria Ionescu (Patient/a0e44abc-acc5-442e-a316-be70192fc72b)
  CNP: 2540203150013 | OTP: 150013
  Condition: Arterial Hypertension (ID: 36d3b343-a8e9-4b7b-bcfc-52dfe5c51073)
  Medications: 2 active
  Appointments: 3 fulfilled (April 22) + booked
  Observations: 6 (3 exam + 3 survey) — all categories correct

Binary storage: file:///var/medplum/storage (confirmed working)

**FHIR extension URL consistency (all confirmed matching Flutter ↔ doctor UI):**
  https://telemed-bogheanu.ro/fhir/ext/reviewed-by-target
  https://telemed-bogheanu.ro/fhir/ext/reviewed-by
  https://telemed-bogheanu.ro/fhir/ext/session-category
PATCH format confirmed: application/json-patch+json (not merge-patch — Medplum 5.1.10 rejects merge-patch with 400)

### Demo Login Credentials

| Patient | CNP | OTP |
|---|---|---|
| Maria Ionescu (72, Hipertensiune) | 2540203150013 | 150013 |
| Ion Popescu (77, Diabet) | 1490815150027 | 150027 |
| Elena Dumitrescu (63, Artrită) | 2621105150032 | 150032 |
| Gheorghe Stan (70, Cord) | 1551220150048 | 150048 |
| Ana Constantin (78, BPOC) | 2480430150058 | 150058 |

### Practitioner Roles (important — commonly confused)

- **Dr. Elena Ionescu** = Family doctor (Medic de Familie) → shown in Medic tab → `Practitioners.familyDoctorId`
- **Dr. Andrei Popescu** = Pediatric specialist → shown in Specialiști → Pediatrie → `Practitioners.bogheanuId`

---

## Key Architecture Decisions

- **AI is fully on-device** — no cloud API calls for inference; Gemma 4 E4B runs via LiteRT-LM
- **Default language is English** — `LanguageNotifier.build() => 'en'`; toggle in every AppBar
- **Flat navigation + session guard** — `AppNavigationNotifier` manages routing; auth routes protected; use `Navigator.push` for sub-screens (doctors, specialists, legal) to avoid session guard override
- **Dual-write FHIR** — all writes go to local FHIR SDK (guaranteed) + Medplum (best-effort); reads are online-first with local fallback
- **Video calls initiated from confirmed appointment only** — not from Medic tab directly
- **`Trimite mesaj` uses `initialPrompt`** — `Navigator.push(MedicalResponseScreen(initialPrompt:...))` to bypass flat-nav session guard
- **`finalizeConsultation()` has dual guard** — `_finalized` bool on both notifier and screen state prevents duplicate FHIR writes
- **`DateFormatter.format` converts to local time** — stored as UTC ISO, displayed via `dt.toLocal()`

---

## CI / Workflow

- **Workflow:** `.github/workflows/build-apk.yml`
- **Triggers:** push to `main`
- **Steps:** free disk space → checkout → Java 17 → set Android SDK path → Flutter 3.32.0 → pub get → build APK → upload artifact
- **Artifact:** `telemed-debug-apk` (retained 7 days)
- **dart-define in CI:** `--dart-define=MEDPLUM_CLIENT_ID=${{ secrets.MEDPLUM_CLIENT_ID }}` — requires secrets to be set
- **Local Kotlin build:** run via CI only (AAPT2 x86-64 incompatible with GX10 ARM64)

---

## Infrastructure Constraints

- **DuckDNS — 5/5 slots used. No new subdomains available.**  
  Existing: `telemed-b`, `telemed-medplum`, `telemed-medplum-ui`, `telemed-doctor`, `telemed-signal`.  
  Any new public endpoint must reuse one of these via path routing, or share a Caddy block.

- **Doctor UI proxy (port 8767 on GX10)** — needs public exposure without a new subdomain.  
  Recommended solution: add path routing inside the existing `telemed-signal.duckdns.org` Caddy block —  
  signaling stays on 8765 (WebSocket upgrade for `/` or default), proxy UI on 8767 at a distinct path (e.g. `/doctor-proxy`).  
  Alternative: reuse `telemed-doctor.duckdns.org` with path-based routing to distinguish the static UI from any proxy.

- **TURN server** — coturn running on GCP VM port 3478.  
  Credentials: username `telemed` / password `TeleMed_TURN_2026!`  
  ICE config already updated in Flutter (`video_consultation_screen.dart`) and doctor UI (`doctor-ui/index.html`).  
  GCP firewall rule for UDP/TCP 3478, 5349, UDP 49152–65535 still needs to be added.

- **Signaling server** — Node.js `ws` relay running as a systemd service on GX10 port 8765.  
  Service file: `/etc/systemd/system/telemed-signaling.service` (may need `sudo systemctl enable --now telemed-signaling` if not yet persistent).  
  Proxied publicly via `telemed-signal.duckdns.org` → GCP Caddy → WireGuard → GX10:8765.

---

## Immediate Next Actions (in priority order)

1. Make repo public (`gh repo edit --visibility public` or GitHub UI)
2. Record demo video (Maria story)
3. Fix P1 bugs above (items 3–7) — batch into one CI build
4. Fix P2 polish bugs (items 8–12) — batch into one CI build
5. GCP firewall rule: UDP/TCP 3478, 5349, UDP 49152–65535 for TURN server
6. Make signaling server persistent: `sudo systemctl enable --now telemed-signaling`
