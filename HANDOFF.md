# TeleMed_K — Handoff Summary
**Date:** 2026-05-14  
**Deadline:** May 18, 2026 — **4 days remaining**  
**Repo:** https://github.com/RaresBGH/TeleMed_K (still PRIVATE — must go public before deadline)  
**Latest Flutter commit:** build #104 (CI building).  
**Latest device-tested:** build #102 release — confirmed working. Build #104 awaiting CI + device test.  
**Kaggle Writeup:** drafted at /home/corb_d/sovereign-factory/mobile-workspace/TeleMed_K_Writeup.md, finalized to 1498 words, currently at 6/7 on the Kaggle submission checklist (video pending).  
**HuggingFace adapter:** https://huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical (public).

---

## Context

Flutter telemedicine app for rural Romania. Clinica Medicală Dr. Bogheanu in Brănești, Dâmbovița.  
**Authors:** Rareș Bogheanu (project lead, Senior QA architect — 20 years enterprise QA experience at IBM, O2 Telefónica UK, Ubisoft, government digitalization) and Andra Inovan (creative direction, video, design).  
**Clinical partners:** Clinica Medicală Dr. Bogheanu, Brănești, Dâmbovița County: Dr. Adriana Bogheanu (consultant pediatrician), Dr. Mariana Andronescu (family-medicine physician).  
Target users: elderly patients (70s–80s) with low tech literacy; NGO provides devices.  
Competition: Kaggle Gemma 4 Good Hackathon.  
Primary AI: Gemma 4 E4B (3.5GB model, LiteRT-LM 0.11.0) — runs fully on-device.  
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
- Triage chat: voice bubble shows play button; photo bubble shows tappable thumbnail
- AI conversation context maintained across turns (history passed as customPrompt)
- On-device AI inference: WORKING — LiteRT-LM 0.11.0, ENGINE_INIT_ERROR resolved. Green pill confirmed. Voice inference confirmed working. Photo: fallback message returned, no crash, thumbnail tappable. Vision encoder not yet producing responses within 60s timeout.
- GitHub Actions secrets MEDPLUM_CLIENT_ID and MEDPLUM_CLIENT_SECRET confirmed set and working
- Doctor UI sliding panel deployed at https://telemed-doctor.duckdns.org: 2-state panel outside call (Patient Report / Chat); in-call shows Patient Report only; patient triage report with chronic conditions, unreviewed dialogues, Mark reviewed → PATCH reviewed-by extension, Finalize → PATCH status:final; In-Call panel: Activity tab only (last 5 Observations) — Chat removed in build #76; responsive 320px desktop / 280px tablet overlay / full-width mobile; join window -60min to +120min
- All practitioner names replaced with approved mock names throughout app and Medplum
- All 9 specialist Practitioner resources created in Medplum with real UUIDs
- Appointment join grace window: joinable from 60 minutes before to 120 minutes after scheduled time
- Doctor UI deployment: source at doctor-ui/index.html in repo; Caddy serves from /home/corb_d/sovereign-factory/doctor-ui/index.html; deploy with cp command documented in CLAUDE.md
- WaitingRoomScreen STATE B: "See my recent activity" button → bottom sheet with last 5 Observation summaries (date, category chip, AI summary excerpt)
- VideoConsultationScreen: Activity tab only — Chat removed in build #76; last 5 Observations loaded on initState; read-only cards with category chip
- MedicalSessionState.lastPractitionerRef: propagated through all 5 state copy sites (clearPreseed, clearPatientMessage, prepareResume, setDoctorContext, _handleResult); written as reviewed-by-target FHIR extension on finalizeConsultation

---

## Built — Awaiting Device Test

The following are code-complete but not yet confirmed on Pixel 9 Pro:

| Feature | Key risk |
|---|---|
| Returning vs new user detection | FHIR query on seed data |
| Profile completion (new user flow) | FHIR Patient write |
| Dashboard (FHIR condition/medication/appointment) | FHIR read from local SDK |
| H3: ML Kit OCR + voice in Ajutor | ML Kit 15s timeout; first-launch warm-up |
| H5: Back button + Trimite mesaj routing | Navigator.push/pop stack |
| H8: Voice confirm dialog | Dialog dismiss path |
| H9: Document attachment + audio replay | FilePicker + just_audio |
| H12: WebRTC signaling | Requires both peers on same signaling room |
| AI engine rewrite (system prompt, session isolation, streaming shim) | First inference latency |

---

## Outstanding Bugs

### P0 — NONE

### P1 — CONFIRMED OPEN
- Activity panel (VideoConsultationScreen): tap-outside dismiss + title — needs device retest
- Mic not released after video call ends — needs device retest
- Video call quality — needs two-device test
- iPad Safari: chat stripe tap + doctor list empty
- Emergency routing: tel:112 device test pending
- withOpacity → withValues migration pending CI upgrade past Flutter 3.32.x

---

## Fine-Tune Pipeline State (2026-05-12)

### Completed steps

| Step | Script | Output | Status |
|---|---|---|---|
| 5 — Scaffold | tools/finetune/ (uv project) | config.py, pyproject.toml, .env.example | ✅ done |
| 6 — Romanian data | pull_romanian.py | ro_ultrachat_filtered.jsonl (500) + ro_magpie_mt_filtered.jsonl (200) | ✅ done (NOT in first run) |
| 7 — Medical EN | pull_medical.py | medical_chatbot_en.jsonl (600) | ✅ done (NOT in first run) |
| 8 — Seed translations | translate_patient_turns.py | medical_patient_turns_ro.jsonl (21 rows) | ✅ done (seeds only) |
| 9 — Synthetic dialogues | generate_synthetic.py | 121 dialogues across 5 files | ✅ done |
| 10 — Merge/split | merge_train_eval.py | train.jsonl (109) + eval.jsonl (12) | ✅ done |
| 10b — System message injection | merge_train_eval.py (modified) | train.jsonl (109), eval.jsonl (12) with SYSTEM_MESSAGE prepended to every row | ✅ done |
| 11 — QLoRA training | train_gemma4_e4b.py | /home/corb_d/sovereign-factory/models/telemed-k-gemma4-e4b-adapter/adapter/ (162MB safetensors) | ✅ done |
| 12 — Evaluation | evaluate_adapter.py | eval_outputs.jsonl, eval_report.md, eval_metrics.json | ✅ done |
| 13 — HF push | tools/finetune/scripts/push_adapter_to_hf.py | huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical | ✅ done |
| 13b — Flutter integration | lib/core/services/ai_engine_service.dart | System prompt + JSON fence-stripping deployed | ✅ done (awaiting device test) |

### Dataset files (all on GX10)

```
/home/corb_d/sovereign-factory/datasets/
  synthetic/
    synthetic_triage_ro_dry_run.jsonl          5 rows  (synth-001..005)
    synthetic_triage_ro_batch_25a.jsonl        25 rows (synth-006..030)
    synthetic_triage_ro_batch_25b.jsonl        25 rows (synth-031..055)
    synthetic_triage_ro_batch_50c.jsonl        50 rows (synth-056..105)
    synthetic_triage_ro_emergency_batch.jsonl  16 rows (synth-106..121)
  training/
    train.jsonl          109 dialogues, 688 turns
    eval.jsonl           12 dialogues, 66 turns
    merge_manifest.json  full provenance, seed=42
```

### Key design decisions (first training run)
- **Synthetic-only** — no OpenLLM-Ro in first run; base Gemma 4 E4B already fluent in Romanian
- **Assistant turns are stringified JSON** — 6-field schema matching _fallbackResponse in ai_engine_service.dart
- **Emergency dialogues are 2-turn** — patient red-flag → exact template ("Sunați 112 imediat.")
- **Eval is stratified** — 9 themes covered, 3 emergency patterns, 2 vague-patient dialogues
- **seed=42** throughout; merge_manifest.json records all synth-IDs in each split

### Risks for Step 11
- Unsloth aarch64 install: **UNKNOWN** — never tested on GX10 ARM64
- Training time: unknown (first QLoRA run on GB10)
- Memory: 121 dialogues × avg 7 turns × ~200 tokens = ~170k tokens total; should fit in 128GB

## Architectural Decision: Path A3 (2026-05-12)

After Step 12 eval succeeded, investigated three deployment paths for the fine-tuned adapter:

- **Path A1** — convert PEFT adapter → LiteRT-LM format via MediaPipe converter.
  RULED OUT: mediapipe 0.10.18 supports only GEMMA_2B, GEMMA_7B, GEMMA2_2B, PHI_2 model types. No Gemma 4 support. LoRA-applicable models even narrower: GEMMA_2B, GEMMA2_2B, PHI_2 only. The HF discussion (litert-community/gemma-4-E2B-it-litert-lm#7) claimed `model_type="GEMMA_4_E2B"` works but source-code inspection confirmed it does not. Open GitHub issue google-ai-edge/LiteRT#6852 from one month ago asks exactly this question, still unresolved.

- **Path A2** — switch app to MediaPipe LLM Inference API (.task format).
  NOT NEEDED: investigation pending the question of "does base model alone get us there?"

- **Path A3 (CHOSEN)** — keep unmodified `gemma-4-E4B-it.litertlm` on device; drive it with the same engineered system prompt that conditioned the trained adapter.

  Verified empirically on GX10 by running BASE model (no adapter) with the production system prompt on three test prompts (hypertension, chest pain + dyspnea, knee arthritis). All three produced clean structured JSON with all 6 schema fields. Chest pain output matched canonical emergency phrase "Sunați 112 imediat." exactly — actually beats the fine-tuned adapter which paraphrased ("Vă rog să sunați imediat 112. Aceasta este o urgență medicală.") on the same prompt. Only quirk: base wraps output in ```json...``` code fences (resolved by the fence-stripping logic added to `_parseAndNormalize` in Step 13b plus the "Nu folosiți formatare markdown" clause appended to the system prompt).

### Implication for hackathon writeup

The fine-tuned adapter is a published artifact on HuggingFace (proof of work, clinical-data fine-tune methodology validated). The on-device deployment uses the base model + engineered system prompt — honest, defensible, and matches the "sovereign, on-device, no internet" story. The fine-tune story positions as: "we trained a domain adapter and validated it generalizes correctly on held-out eval (Step 12 metrics); we publish the adapter for clinics that want stronger domain adaptation; for the demo, the engineered system prompt drives the unmodified on-device base model with production-quality JSON output."

### Stackable tracks alignment

- Main Track (up to $50k) — qualifies (full submission)
- Impact: Health & Sciences ($10k) — exact match (medical triage, rural family medicine)
- Unsloth Special Tech ($10k) — qualifies via the HuggingFace adapter trained with Unsloth
- LiteRT Special Tech ($10k) — qualifies because the on-device `.litertlm` base model is unchanged and runs via LiteRT-LM 0.11.0

---

## GCP `telemed-proxy` VM operational state (2026-05-13)

### IAM incident and recovery
- The Compute default service account `866957367169-compute@developer.gserviceaccount.com` was found removed from project IAM, causing:
  - OpenTelemetry collector spam on the VM's serial console (PermissionDenied on `monitoring.timeSeries.create`)
  - SSH-in-browser failures with generic "SSH authentication has failed" (OS Login backend depended on the service account)
  - No logs (including sshd) reaching Cloud Logging (logging agent couldn't write)
- Restored: granted `roles/editor` to the Compute default service account via GCP Console → IAM & Admin → IAM → Grant Access. The Google-provided role grants checkbox was needed to see the existing principals.
- The instance-level SSH keys metadata had a stale persistent key (`rares.bogheanu` ed25519, dot-form) and two expired temp keys (`rares_bogheanu` underscore-form). All replaced with a single fresh persistent key pushed via gcloud from Cloud Shell.
- VM reset was required to make services pick up the restored IAM — `gcloud compute instances reset telemed-proxy --zone=europe-west3-c`.

### Architecture clarification
- `telemed-proxy` (GCP VM, 34.185.191.34, europe-west3-c) is a Caddy reverse-proxy fronting 5 domains:
  - `telemed-b.duckdns.org` → static file server at `/home/rares_bogheanu/` (model downloads)
  - `telemed-medplum.duckdns.org` → `10.0.0.2:8103` (Medplum FHIR API on GX10 via WireGuard)
  - `telemed-medplum-ui.duckdns.org` → `10.0.0.2:8104` (Medplum admin UI)
  - `telemed-doctor.duckdns.org` → `10.0.0.2:8106` (Doctor UI, served by Caddy on GX10)
  - `telemed-signal.duckdns.org` → `10.0.0.2:8765` (WebRTC signaling)
- All four reverse-proxy targets point at the GX10 (10.0.0.2) over the WireGuard tunnel.
- Caddy on `telemed-proxy` is currently running as PID 366 outside the systemd unit (the systemd `caddy.service` failed at boot because PID 366 owns the ports). Reloads must use `sudo caddy reload --config /etc/caddy/Caddyfile`, not `systemctl reload caddy`. Next VM reboot should resolve this naturally.

### Caddy basic_auth gate on Doctor UI (2026-05-13)
- Added a `basic_auth` block to the `telemed-doctor.duckdns.org` directive in `/etc/caddy/Caddyfile`:
  - Username: `demo`
  - Password: `telemed2026`
  - Bcrypt hash applied via `caddy hash-password --plaintext "telemed2026"`
- Verified: anonymous request returns HTTP/2 401 with `WWW-Authenticate: Basic realm="restricted"`; authenticated request with `demo:telemed2026` returns HTTP/2 200 + Doctor UI HTML.
- Credentials match what's published in the Kaggle Writeup demo section.

---

## Kaggle Writeup finalization (2026-05-13)

### Content shape
- Drafted at `/home/corb_d/sovereign-factory/mobile-workspace/TeleMed_K_Writeup.md` (filename has underscore, not space).
- Final word count: 1498 (under the 1500-word penalty threshold).
- Head-to-head comparison added: adapter vs. base + system prompt across 12 eval dialogues. Both achieve perfect JSON parse, schema, and emergency-flag accuracy. Adapter wins on greeting-rule compliance (0 vs 3 violations) and response conciseness (18.2 vs 22.7 avg words). Base wins on canonical-phrase fidelity (2/3 vs 0/3 — base reproduces "Sunați 112 imediat." verbatim; adapter paraphrases). On the anaphylaxis case (synth-116), the adapter stays anchored to the patient's stated symptoms while the base drifts to off-symptom chest-pain clarification.
- Engineering takeaway in writeup: 121 synthetic dialogues teach Gemma 4 E4B conversational discipline reliably, but cannot consistently override its pre-training priors on canonical safety phrases.
- Deployment decision in writeup: ship the unmodified base on device. Safety routing parity (3/3 TP for both systems) plus LiteRT-LM compatibility (PEFT-to-litertlm conversion path not publicly documented for Gemma 4) make the base the practical choice.

### Base-model evaluation script
- New tool: `tools/finetune/evaluate_base.py` — same protocol as `evaluate_adapter.py` but evaluates the unmodified base. Adds a `canonical_phrase_fidelity` metric (exact substring match for medical emergency / suicidal-ideation canonical phrases).
- Output artifacts: `eval_base_outputs.jsonl`, `eval_base_report.md`, `eval_base_metrics.json` in `/workspace/output/`, alongside the adapter eval artifacts.

### Track selection
- Primary: Impact Track — Health & Sciences.
- Special Technology eligibility: LiteRT (unmodified `.litertlm` runs on device via LiteRT-LM 0.11.0).
- Unsloth Special Tech: not claimed in the writeup. Rules permit "a Main Track Prize and a Special Technology Prize" (singular), and LiteRT is the better fit for what we actually deployed. The fine-tuned adapter remains a published deliverable on HuggingFace.

### Cover image
- Andra (Andra Inovan, creative co-author) delivered a designed cover combining a real photograph of Clinica Medicală Dr. Bogheanu (golden-hour, elderly woman in traditional Romanian ia blouse at the garden arch, the "CLINICA MEDICALĂ DR. BOGHEANU" sign visible) with text overlay: "TeleMed_K / Sovereign telehealth for rural family medicine / From symptom intake to video consultation / On-device AI · Self-hosted FHIR / Built with Gemma 4 E4B". The clinic photo was originally captured by Rareș, then run through nano banana for golden-hour relighting and the addition of the foreground figure.
- Aspect ratio note: Kaggle Writeup card image field specifies 560×280 (2:1). Andra's cover was designed at 16:9; Kaggle accepted the upload (writeup checklist advanced to 6/7) and likely center-crops smaller for thumbnails. To verify final render, click Preview at top-right of the Kaggle Writeup form.

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
- coturn INSTALLED AND RUNNING — active since 2026-05-05, confirmed healthy. GCP VPC firewall rule telemed-turn-relay added 2026-05-08: UDP 49152–65535 + TCP/UDP 5349. Port 3478 was already open. Video stability past 15s awaiting call confirmation.

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
  GCP firewall rule telemed-turn-relay ADDED 2026-05-08 — covers UDP 49152–65535 + TCP/UDP 5349. Port 3478 was already open. TURN relay path now unblocked. Awaiting two-device call test confirmation.

- **Signaling server** — Node.js `ws` relay running as a systemd service on GX10 port 8765.  
  Service file: `/etc/systemd/system/telemed-signaling.service` (may need `sudo systemctl enable --now telemed-signaling` if not yet persistent).  
  Proxied publicly via `telemed-signal.duckdns.org` → GCP Caddy → WireGuard → GX10:8765.

---

## Next Actions (2026-05-14 — 4 days to deadline)

1. Install build #104 release APK — full regression test (text/voice/photo/finalize/dossier)
2. Two-device video call test (confirm TURN fix)
3. Device test: Activity panel dismiss + title
4. Device test: mic release after call
5. Device test: emergency 112 dial
6. iPad Safari fixes
7. Database cleanup (wipe test dialogues, keep Ion + Maria seeded data)
8. Make repo public on GitHub
9. Record demo video (TeleMed Hearth, Maria story)
10. Final Kaggle submission before May 18
