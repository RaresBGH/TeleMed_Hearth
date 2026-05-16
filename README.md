# TeleMed Hearth

**Sovereign telehealth for rural Romanian family medicine.**

From symptom intake to video consultation, on Gemma 4 E4B. Every word a patient speaks stays on their phone or in the clinic — never in the cloud.

---

## What it is

An on-device clinical-intake and teleconsultation platform built for elderly rural patients in Romania. The app conducts a structured medical triage in Romanian (or English), entirely on the patient's phone via Gemma 4 E4B, then connects the patient to their family doctor by WebRTC video. The doctor reviews the AI-generated triage alongside the live call, marks the consultation reviewed, and the record persists in the clinic's self-hosted FHIR server.

No AI inference crosses the public internet. No telemetry. No analytics. The AI lives on the phone; the records live in the clinic.

The full project narrative — what the product does, what we built with Gemma 4, the architectural challenges we worked through — is in **[TeleMed_Hearth_Writeup.md](TeleMed_Hearth_Writeup.md)**.

---

## Hackathon submission

**Kaggle Gemma 4 Good — Impact Track: Health & Sciences.** Special Technology eligibility: **LiteRT** (the unmodified `.litertlm` runs on device through LiteRT-LM 0.11.0).

Deliverables:
- **Writeup:** [TeleMed_Hearth_Writeup.md](TeleMed_Hearth_Writeup.md)
- **Code:** this repository
- **Demo video:** linked in the writeup's Media Gallery
- **LoRA adapter:** [huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical](https://huggingface.co/CoRBs/telemed-k-gemma4-e4b-ro-medical) — published as a deliverable artifact with full evaluation metrics and head-to-head comparison against the base model

---

## Try the demo

### Patient app

Install the debug APK from the [Releases page](https://github.com/RaresBGH/TeleMed_Hearth/releases). On first launch, the app downloads the Gemma 4 E4B model (~3.5 GB, WiFi recommended, one-time).

Sign in with one of the seeded patients:

| Patient | Condition | CNP | OTP |
|---|---|---|---|
| Maria Ionescu, 72 | Hypertension | 2540203150013 | 150013 |
| Ion Popescu, 77 | Type-2 Diabetes | 1490815150027 | 150027 |
| Elena Dumitrescu, 63 | Arthritis | 2621105150032 | 150032 |
| George Constantin, 70 | Atrial Fibrillation | 1551220150048 | 150048 |

The OTP is the last 6 digits of the CNP — derived locally so judges can sign in without an SMS gateway. Production uses Google SmartAuth for real OTP retrieval.

Tap **+ Înregistrare problemă nouă** (New issue), describe a symptom by voice, photo, or text. For chest pain with shortness of breath, the 112 dialer fires.

### Doctor UI

Visit **[telemed-doctor.duckdns.org](https://telemed-doctor.duckdns.org)** — credentials `demo` / `telemed2026` (a basic-auth gate over the real Medplum OAuth2 client-credentials flow, for demo protection).

See today's appointments, the AI-generated triage report, the WebRTC waiting room, and the consultation-finalize flow. UI language defaults to Romanian; toggle EN/RO in the top-right.

---

## How it works

Four layers, one sovereignty boundary:

1. **Patient app** — Flutter (Dart) + Android-native (Kotlin) bridge to LiteRT-LM. Encrypted SQLite at rest via SQLCipher 4.6.1. Local FHIR persistence through Google's Android FHIR SDK 1.2.0.
2. **On-device AI** — Gemma 4 E4B in `.litertlm` form, driven by LiteRT-LM 0.11.0. Voice (WAV 16 kHz mono), photos (JPEG), and text all multiplex through the same `Engine` handle per session.
3. **Clinical records** — Self-hosted Medplum 5.1.10 (FHIR R4) on an NVIDIA GB10 server (Grace Blackwell, ARM64, 128 GB unified memory). Dual-write: every Observation, Appointment, and Communication is written to local SQLite first, then best-effort to Medplum.
4. **Doctor browser** — Vanilla-JS WebRTC client served by Caddy. Joins a signaling room keyed by `appointmentId`; the in-call side panel shows the AI triage report alongside the live video.

AI inference is air-gapped from the public internet. Records traverse a WireGuard tunnel from device → a small GCP reverse proxy → Caddy → Medplum on the clinic's GB10. WebRTC media is peer-to-peer between phone and browser, with coturn for NAT-traversal fallback.

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
├── tools/                        Maintenance scripts (Medplum, CNP)
├── test/, integration_test/      Tests
├── DESIGN.md                     Design system ("Empathetic Brutalism")
├── HANDOFF.md                    Working features, outstanding bugs, deployment state
├── TELEMED_CONTEXT.md            Full architectural context, build history
└── TeleMed_Hearth_Writeup.md     Hackathon narrative
```

---

## Build from source

**Requirements:** Flutter 3.32.0 (stable), Android SDK 34, JDK 17, an Android device or emulator with ≥ 6 GB RAM.

```bash
flutter pub get
flutter build apk --debug \
  --dart-define=MEDPLUM_CLIENT_ID=<your-medplum-client-id> \
  --dart-define=MEDPLUM_CLIENT_SECRET=<your-medplum-client-secret>
```

Without the Medplum credentials the app still runs but writes will be local-only (the dual-write to Medplum will fail gracefully).

CI builds via `.github/workflows/build-apk.yml` on every push to `main`; the resulting debug APK is uploaded as a build artifact (retained 7 days).

For a production-grade deployment (your own Medplum, your own signaling, your own doctor UI), see **[TELEMED_CONTEXT.md](TELEMED_CONTEXT.md)** for the full infrastructure layout.

---

## Honest boundaries

TeleMed Hearth is not a diagnostic tool — it documents, triages, and routes; humans diagnose. The training data is synthetic and partner-clinic-reviewed at a single rural site; broader clinical validation is required before any scaled deployment. Every interaction produces an FHIR record for a physician to review and finalize, and one-tap *Anulează* exits the AI intake at any point.

---

## Documentation

- **[TeleMed_Hearth_Writeup.md](TeleMed_Hearth_Writeup.md)** — hackathon narrative, the "what and why"
- **[DESIGN.md](DESIGN.md)** — design system ("Empathetic Brutalism") for elderly-rural-patient UX
- **[HANDOFF.md](HANDOFF.md)** — verified working features, outstanding bugs, deployment state
- **[TELEMED_CONTEXT.md](TELEMED_CONTEXT.md)** — full project context, infrastructure, build history, architectural decisions

---

## Authors

**[Rareș Bogheanu](https://www.linkedin.com/in/corbd/)** — project lead. Senior QA architect with two decades of enterprise QA experience (IBM SAN/storage, Telefónica UK billing migration, Ubisoft AAA multiplayer QA, government CRM digitalization).

**[Andra Inovan](https://www.linkedin.com/in/andra-tiana-inovan/)** — creative direction, video, design.

Clinical review: Dr. Adriana Bogheanu and Dr. Mariana Andronescu reviewed all 121 synthetic training dialogues at a rural Dâmbovița County practice.

---

## License

See [LICENSE](LICENSE).
