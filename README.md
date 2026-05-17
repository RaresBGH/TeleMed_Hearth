# TeleMed Hearth

**Sovereign telehealth for rural Romanian family medicine.**

From symptom intake to video consultation, on Gemma 4 E4B. Every word a patient speaks stays on their phone or in the clinic — never in the cloud.

---

## What it is

An on-device clinical-intake and teleconsultation platform built for elderly rural patients in Romania. The app conducts a structured medical triage in Romanian (or English), entirely on the patient's phone via Gemma 4 E4B, then connects the patient to their family doctor by WebRTC video. The doctor reviews the AI-generated triage alongside the live call, marks the consultation reviewed, and the record persists in the clinic's self-hosted FHIR server.

AI inference never crosses the public internet. Clinical records traverse a WireGuard tunnel through a GCP reverse-proxy VPS that performs no storage or processing, then land in the clinic's self-hosted Medplum FHIR server. No third-party LLM API. No analytics SDKs. No telemetry.

The full project narrative is in **[TeleMed_Hearth_Writeup.md](TeleMed_Hearth_Writeup.md)**.

---

## Hackathon submission

**Kaggle Gemma 4 Good** - Main Track eligibility
Special Technology eligibility: **LiteRT** (the unmodified `.litertlm` runs on device through LiteRT-LM 0.11.0). 
Impact Track eligibility: **Health & Sciences** 

- **Code:** this repository
- **Demo video:** <DEMO_VIDEO_URL>
- **LoRA adapter:** [huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical](https://huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical) — published as a deliverable artifact with full evaluation metrics and head-to-head comparison against the base model

---

## Try the demo

### Patient app

Download the latest signed release APK from the [Releases page](https://github.com/RaresBGH/TeleMed_Hearth/releases). On first launch, the app downloads the Gemma 4 E4B model (~3.5 GB, WiFi recommended, one-time).

Sign in with one of the seeded patients:

| Patient | Condition | CNP | OTP |
|---|---|---|---|
| Maria Ionescu, 72 | Hypertension | 2540203150013 | 150013 |
| Ion Popescu, 77 | Type-2 Diabetes | 1490815150027 | 150027 |
| Elena Dumitrescu, 63 | Arthritis | 2621105150032 | 150032 |
| George Constantin, 70 | Atrial Fibrillation | 1551220150048 | 150048 |

The OTP is the last 6 digits of the CNP — derived locally so judges can sign in without an SMS gateway. Production uses Google SmartAuth for real OTP retrieval.

Tap **+ Register new issue** , describe a symptom by voice, photo, or text. For chest pain with shortness of breath, the 112 dialer fires.

### Doctor UI

Visit **[telemed-doctor.duckdns.org](https://telemed-doctor.duckdns.org)** — credentials `demo` / `telemed2026` (a basic-auth gate over the real Medplum OAuth2 client-credentials flow, for demo protection).

See today's appointments, the AI-generated triage report, the WebRTC waiting room, and the consultation-finalize flow. UI language defaults to Romanian; toggle EN/RO in the top-right.

---

## How it works

Four layers, one sovereignty boundary:

1. **Patient app.** Flutter (Dart) + Android-native (Kotlin) bridge to LiteRT-LM. Encrypted SQLite at rest via SQLCipher 4.6.1. Local FHIR persistence through Google's Android FHIR SDK 1.2.0.
2. **On-device AI.** Gemma 4 E4B in `.litertlm` form, driven by LiteRT-LM 0.11.0. Voice (WAV 16 kHz mono), photos (JPEG), and text all multiplex through the same `Engine` handle per session.
3. **Clinical records.** Self-hosted Medplum 5.1.10 (FHIR R4) on an NVIDIA GB10 server (Grace Blackwell, ARM64, 128 GB unified memory). Dual-write: every Observation, Appointment, and Communication is written to the local FHIR SDK first, then best-effort to Medplum.
4. **Doctor browser.** Vanilla-JS WebRTC client served by Caddy. Joins a signaling room keyed by `appointmentId`; the in-call side panel shows the AI triage report alongside the live video.

The sovereignty boundary is precise: AI inference is air-gapped from the public internet. Records traverse a WireGuard tunnel from device → a small GCP e2-micro reverse proxy (Frankfurt) → Caddy → Medplum on the clinic's GB10. The VPS is an ingress only; no record processing or storage. WebRTC signaling rides the same tunnel; WebRTC media is peer-to-peer between phone and browser, with coturn on the VPS for NAT-traversal fallback. DuckDNS DNS-01 issues TLS for `telemed-medplum.duckdns.org`, `telemed-doctor.duckdns.org`, and `telemed-signal.duckdns.org`.

---

## On-device AI vs. the published LoRA adapter

The TeleMed Hearth Android app ships the **unmodified base** `gemma-4-E4B-it.litertlm`, driven by the same Romanian system prompt that conditioned the LoRA fine-tune training. This is a deliberate engineering choice, not a fallback.

A domain-adapted LoRA adapter was trained on 121 synthetic Romanian rural-elderly triage dialogues and published as a separate deliverable at [huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical](https://huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical). The adapter is NOT used on-device, for two reasons:

1. **LiteRT-LM 0.11.0 does not currently support merging a PEFT LoRA adapter into the `.litertlm` runtime format.** MediaPipe's available converters target only `GEMMA_2B`, `GEMMA2_2B`, and `PHI_2`. There is no public conversion path from a Gemma 4 LoRA adapter to a deployable on-device artifact at this time.
2. **The head-to-head evaluation favored the base for the property that matters most.** Both systems achieve perfect safety routing on the held-out evaluation (3/3 emergency true positives, 0 false negatives). The adapter wins on register and discipline (0 vs. 3 greeting-rule violations; 18.2 vs. 22.7 average words per response). The base wins on canonical-phrase fidelity — it reproduces `"Sunați 112 imediat."` verbatim on 2 of 3 emergency cases; the adapter paraphrases. For on-device deployment where the application layer routes on the `emergency` boolean (not the response string), the base + system prompt is the more practical choice.

The adapter remains published as a hackathon deliverable artifact for server-mediated deployments of Romanian medical triage, and as a reference for researchers evaluating register adaptation on Gemma 4 E4B. The HuggingFace model card carries the full head-to-head evaluation table.

---

## Repository layout

```
.
├── lib/                          Flutter / Dart source
│   ├── ui/screens/               All visible screens
│   ├── core/
│   │   ├── services/             AI engine, audio, camera, Medplum, FHIR
│   │   ├── providers/            Riverpod state
│   │   ├── l10n/                 AppStrings (RO + EN)
│   │   └── utils/                Date formatting, CNP, FHIR helpers
│   └── data/repositories/        Repository facades over local FHIR + Medplum
├── android/                      Native Kotlin (LiteRT-LM bridge, OCR, audio)
├── doctor-ui/                    Vanilla-JS WebRTC client + Patient Report panel
├── model_training/               LoRA fine-tune pipeline (Gemma 4 E4B + Unsloth)
├── tools/                        Maintenance scripts (Medplum, CNP, finetune)
├── test/, integration_test/      Tests
├── DESIGN.md                     Design system ("Empathetic Brutalism")
└── TeleMed_Hearth_Writeup.md     Hackathon narrative
```

---

## Build from source

**Requirements:** Flutter 3.32.0 (stable), Android SDK 36, JDK 17, an Android device or emulator with ≥ 6 GB RAM.

```bash
flutter pub get
flutter build apk --release \
  --dart-define=MEDPLUM_CLIENT_ID=<your-medplum-client-id> \
  --dart-define=MEDPLUM_CLIENT_SECRET=<your-medplum-client-secret> \
  --dart-define=TURN_USERNAME=<your-coturn-username> \
  --dart-define=TURN_CREDENTIAL=<your-coturn-password>
```

Without the Medplum credentials the app still runs but writes will be local-only (the dual-write to Medplum will fail gracefully and the in-memory state remains consistent). Without TURN credentials, video calls work only when both peers can reach each other directly (no NAT-relay fallback).

CI builds via `.github/workflows/build-apk.yml` on every push to `main`. Both debug and release APKs are uploaded as build artifacts (retained 7 days). The release APK linked from the [Releases page](https://github.com/RaresBGH/TeleMed_Hearth/releases) is the recommended demo build.

For a production-grade deployment (your own Medplum, your own signaling, your own doctor UI), the layered architecture above is reproducible from this repository's source.

---

## Engineering challenges, resolved

These are the six hardest engineering problems we worked through. Each is documented here so the writeup can keep its narrative focus and so anyone forking this repo understands the trade-offs we accepted.

### 1. Training-inference parity for structured output

Our first QLoRA fine-tune produced fluent Romanian triage prose with no JSON wrapping — Gemma 4's instruction-following prior overwhelmed our 121-example signal. We diagnosed by decoding the tokenized training inputs and confirming the chat template preserved the JSON literals byte-for-byte. The fix was to prepend the production system message to every training row, identical to inference. Retraining produced clean structured JSON on every held-out dialogue.

The lesson generalizes: at this dataset size, training-time and inference-time conditioning must match byte-for-byte for structured-output tasks. We applied the same principle to the on-device system prompt (`buildSystemPrompt()` in `ai_engine_service.dart`) — it is the exact Romanian message used as the training-time system role, with one runtime substitution (`Maximum 30 cuvinte per propoziție` to match training-data validator output).

### 2. ARM64 Grace Blackwell training toolchain

The clinic's NVIDIA GB10 (Blackwell, aarch64) is the entire training and serving substrate. Standard PyTorch wheels are unstable on Blackwell aarch64; we pinned `torchao==0.16.0` against the NGC Blackwell PyTorch build. Unsloth's QLoRA path works correctly on this toolchain only with a specific transformers/trl/peft triple (5.5.0 / 0.24.0 / 0.19.1) — anything else triggered Triton compilation errors on the Blackwell SMs.

Gemma 4's chat template additionally broke the standard tokenizer diagnostic path; we worked around it via direct tensor inspection until upstream fixes propagated. The training run itself (3 epochs, 121 dialogues, effective batch 4) finishes in well under an hour on a single Blackwell GPU — the GB10's 128 GB unified memory eliminates the staging-buffer dance that QLoRA usually requires.

### 3. Emergency-flag end-to-end plumbing

The on-device chain — JSON `emergency: true` → exception raised in `ai_engine_service.dart` → `SessionState.emergency` in the session provider → navigation override to the Emergency screen → `url_launcher` firing `tel:112` — required verification on a real Pixel device under model load, with the foreground service holding the inference engine. We hold this verification as table stakes for shipping anything that claims to triage emergencies.

The current implementation throws `EmergencyFlagException` at three call sites (text, voice, photo evaluations) in `ai_engine_service.dart`, caught in `medical_session_provider.dart`, routed via `app_navigation_provider.dart`. Both Romanian canonical phrases (`"Sunați 112 imediat."` and the suicidal-ideation hotline message with `0800 801 200`) are present in the on-device system prompt with explicit reproduction instructions. The base model verbatim-reproduces the 112 phrase on 2 of 3 emergency held-out cases (see the HuggingFace card's head-to-head evaluation); the application layer routes on the boolean flag regardless of phrasing.

### 4. Medplum FHIR custom-search-parameter indexing

We needed re-join chat threads scoped per-Observation: every doctor message stored as a `Communication` with `about: [{reference: "Observation/{id}"}]`. The natural query — `GET /Communication?about=Observation/{id}` — returns empty in Medplum 5.1.10 because the FHIR `Communication.about` SearchParameter is not indexed in their default configuration, and the super-admin `$reindex` operation returns 403 from the standard authenticated client.

We resolved this with a client-side filter pattern: fetch all Communications scoped to the patient (`subject=Patient/{patientId}&_count=200`), then JS-side filter by `about[0].reference === 'Observation/{observationId}'`. This is documented in `medical_response_screen.dart`'s `_loadObsCommunications` and mirrored in the doctor UI. The proper fix — running a Medplum container-level `$reindex` to populate the index — is on the post-hackathon roadmap; the current pattern works correctly within reasonable thread sizes (the patient's full Communication history is small enough that 200-item windowing is never reached in practice).

### 5. Hybrid storage tension (Observation.note vs. Communication)

A consequence of incremental product evolution: the original AI-triage transcript is written to `Observation.note[0].text` as a newline-joined `[AI HH:MM]: ...` / `[Pacient HH:MM]: ...` stream, finalized once at session close. Doctor messages and PDF attachments arrive AFTER finalization, so they cannot live in the same Observation note (it's already written and the consultation is closed); they are stored as separate `Communication` resources with `about: Observation/{id}`.

This bifurcation has two practical consequences:
- Reading a closed dialog requires two queries (Observation note text + filtered Communications) and a merge.
- Timestamps need reconstruction: note lines carry only `HH:MM` prefixes; we reconstruct full DateTimes by combining the prefix with `Observation.effectiveDateTime`'s date portion.

The reconstruction is implemented in `_parseTranscriptWithTimestamps` and works correctly for the four-patient demo dataset. The post-hackathon refactor is unified Communications-only storage — every turn (AI, patient, doctor) lives as a Communication; the Observation carries only the structured summary fields and the final `valueString`. This eliminates the parser, the merge, the timestamp reconstruction, and the `DialogDetailSheet` parse logic, replacing them with a single chronological-sort query.

### 6. FHIR dual-write ID alignment

The patient app dual-writes every FHIR mutation: local first (Google Android FHIR SDK + SQLCipher), then Medplum HTTP best-effort. The local SDK is seeded at first launch with four mock patients whose IDs are local-only strings (`mock-patient-0` through `mock-patient-3`). At runtime, the app fetches the corresponding Medplum Patient by CNP search, which returns the canonical Medplum UUID. Subsequent in-app updates carry the Medplum UUID — but the local SDK's `fhirEngine.update(patient)` is strict (not upsert) and throws `ResourceNotFoundException` because the local SDK has no record with that Medplum UUID, only the mock seed ID.

For most of the development cycle this manifested as a silent broken leg of the dual-write — Medplum committed, local errored, the user-visible outcome appeared correct because reads went online-first to Medplum. The profile-photo upload flow was the first surface to expose the broken leg, because it caught and reported the local-side exception to the user.

We patched the orchestrator (`FhirRepository.updatePatient`) to tolerate partial success: both writes are attempted independently; success of either is reported as success of the operation; both failing is the only error path. This is documented in code as the workaround; the real fix is one of (a) align local-seed IDs to Medplum UUIDs at first-launch hydration time, or (b) migrate the local-SDK update to upsert semantics via `fhirEngine.create()` fallback on `NotFound`. Both are post-hackathon.

---

## Honest boundaries

TeleMed Hearth is not a diagnostic tool — it documents, triages, and routes; humans diagnose. The training data is synthetic and partner-clinic-reviewed at a single rural site (Clinica Medicală Dr. Bogheanu, Brănești, Dâmbovița County, Romania); broader clinical validation is required before any scaled deployment. Every interaction produces an FHIR record for a physician to review and finalize, and one-tap *Anulează* exits the AI intake at any point.

The on-device AI is conditioned to never name medications, never interpret tests, never diagnose. The structured-output JSON the model emits is parsed by the application; the application is what makes routing decisions (emergency 112 dialer, finalize button, FHIR category). The model is a clinical-intake conversationalist with a strict output contract, not an oracle.

The published LoRA adapter and the head-to-head evaluation against the base model are public deliberately. We believe a sovereign on-device medical-triage system is more credible when its model card discloses what its fine-tune did and did not improve.

---

## Documentation

- **[TeleMed_Hearth_Writeup.md](TeleMed_Hearth_Writeup.md)** — hackathon narrative, the "what and why"
- **[DESIGN.md](DESIGN.md)** — design system ("Empathetic Brutalism") for elderly-rural-patient UX
- **HuggingFace model card** — [adapter card](https://huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical) with training config, head-to-head evaluation, and deployment-compatibility notes

---

## Authors

**[Rareș Bogheanu](https://www.linkedin.com/in/corbd/)** — project lead. 

**[Andra Inovan](https://www.linkedin.com/in/andra-tiana-inovan/)** — creative direction, video, design.

---

## License

See [LICENSE](LICENSE).
