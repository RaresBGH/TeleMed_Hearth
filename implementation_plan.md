# VitalEase Production v1.0: Local, Accessible Telemedicine App for Seniors

This document outlines the architectural plan for building VitalEase, an offline-first telemedicine Flutter app tailored for rural seniors. The project acts as a functional medical assistant buffering sessions as HL7 FHIR constructs, utilizing local AI inference via Gemma 4 E2B, and syncing with a Medplum EHR backend.

## Scope & Platform Limitations
- **Platform:** Strictly an **Android application**. iOS support is completely dropped, targeting budget Android devices commonly used in rural areas. 
- **Data Sovereignty:** We are natively integrating the Google Android FHIR SDK and Medplum to ensure total compliance with the upcoming Summer 2026 PIAS/DES integration.

---

### 1. Data Layer: FHIR & Database (Completed)
Using an encrypted SQLite setup paired with the Google Android FHIR SDK to buffer `Observation` and `Condition` resources.
- **`fhir_repository.dart`:** Initializes the local FHIR SDK engine and encrypted SQLite database, enforcing SQLCipher encryption-at-rest. Provides CRUD operations for local health dossiers.
- **`fhir_sync_service.dart`:** Handles offline-to-cloud synchronization natively pushing to the Medplum EHR backend over stable Wi-Fi/4G.

---

### 2. AI Engine Layer: Local Inference & RAG (Active Updates Required)
Wrapper around Google LiteRT-LM for Gemma 4 E2B capabilities directly on the local TPU/NPU.
- **`ai_engine_service.dart`:** 
  - `initializeModel()` & `downloadWeights()`: Loads the ~2.58 GB 4-bit quantized Gemma 4 E2B model from local storage (downloaded over Wi-Fi on first launch).
  - `evaluateAudio(File audioFile)`: Feeds raw audio directly to the LiteRT-LM model bypassing external STT.
  - **[PHASE 7 NEW] `evaluateMedia(File mediaFile)`:** Leverages Gemma 4's native multimodal vision capabilities to process images and video (up to 60 seconds) directly into FHIR Observations without third-party OCR.
  - **On-Device RAG:** Silently queries the `FhirRepository` to inject the patient's historical FHIR dossier into the 128K context window prior to evaluation.
  - **Rules Engine:** Constrained JSON output. Throws an emergency state flag if `{"emergency": true, "confidence": >0.8}` is detected.

---

### 3. State Management & Telemedicine Bridge (Active Updates Required)
- **`medical_session_provider.dart`:** Manages the user's active session state and orchestrates audio/media capture to the AI engine.
- **`app_navigation_provider.dart`:** Aggressively overrides the router to push the **Urgență** screen upon an `EmergencyFlagException`.
- **[PHASE 7 NEW] `telemedicine_service.dart`:** Implements a WebRTC listener connected to the Medplum backend to receive incoming video consultations from the physician.

---

### 4. Elderly-Centric UI & Screen Overrides (Active Updates Required)
Applying our CC-BY 4.0 UI design system constraints and specific Stitch screen overrides.
- **`theme.dart`:** Deep off-white backgrounds (#F5F5F5) with pure `#000000` text. Minimum `18sp` font size. Enforces `64x64 dp` minimum touch targets.
- **`home_screen.dart`:** Massive screen-filling microphone icon. Top-right camera icon wired to `evaluateMedia()`. Persistent bottom navigation (Acasă, Istoric, Doctorul Meu).
- **`confirmation_screen.dart`:** Redundant 'Înapoi' button removed to prevent cognitive overload.
- **`emergency_screen.dart`:** High-alert 112 handoff screen with 2px solid black borders on secondary buttons.
- **[PHASE 7 NEW] `history_screen.dart`:** The visual representation of the patient's local SQLite FHIR dossier, adhering to the 18sp and 64dp accessibility rules.
