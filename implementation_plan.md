\# TeleMed\_K: Local, Accessible Telemedicine App for Seniors

This document outlines the architectural plan for building TeleMed\_K, an offline-first telemedicine Flutter app tailored for rural seniors. The project acts as a functional medical assistant buffering sessions as HL7 FHIR constructs and using local AI inference.

\#\# Scope & Platform Limitations  
\- \*\*Platform:\*\* Strictly an \*\*Android application\*\*. iOS support is completely dropped, targeting budget Android devices commonly used in rural areas. We are natively integrating the Google Android FHIR SDK.

\#\# Proposed Changes

We will strictly enforce layer separation and introduce specific UI overrides to pass the required WCAG AAA accessibility rules.

\---

\#\#\# 1\. Data Layer: FHIR & Database

Using an encrypted SQLite setup paired with the Google Android FHIR SDK to buffer \`Observation\` and \`Condition\` resources.

\#\#\#\# \[NEW\] \[fhir\_repository.dart\](file:///Users/crb/Documents/TeleMed\_K/lib/data/repositories/fhir\_repository.dart)  
\- Initializes the local FHIR SDK engine and encrypted SQLite database.  
\- Provides CRUD operations (saving observations mapped from user voice sessions).  
\- Sync status tracking (offline-first, buffers actions to send to cloud once connection is restored).

\---

\#\#\# 2\. AI Engine Layer: Local Inference

Wrapper around Google LiteRT-LM for Gemma 4 E2B capabilities directly on the local TPU/NPU.

\#\#\#\# \[NEW\] \[ai\_engine\_service.dart\](file:///Users/crb/Documents/TeleMed\_K/lib/core/services/ai\_engine\_service.dart)  
\- \`initializeModel()\`: Handles the loading of the \`Gemma 4 E2B\` model.  
\- \`downloadWeights()\`: Facilitates an initial Wi-Fi download of the \~2.58 GB 4-bit quantized Gemma 4 E2B model upon the first application launch. Weights will NOT be bundled in the APK; they will be saved to local device storage.  
\- \`evaluateAudio(File audioFile)\`: Feeds the raw collected audio file directly to the LiteRT-LM model. (No intermediary STT parsing is used, leveraging Gemma 4 E2B's native audio input processing).  
\- \*\*Rules Engine:\*\* The model provides constrained JSON output. If \`{"emergency": true, "confidence": \>0.8}\` is detected from the raw audio processing, it throws an emergency state flag.

\---

\#\#\# 3\. State Management (Riverpod)

Centralizes state transitions between capturing audio, analyzing it, and triggering navigation.

\#\#\#\# \[NEW\] \[medical\_session\_provider.dart\](file:///Users/crb/Documents/TeleMed\_K/lib/core/providers/medical\_session\_provider.dart)  
\- Manages the user's active session.  
\- Orchestrates calling \`audio\_service\` to capture audio, passing the raw \`File\` to \`ai\_engine\_service\`, and updating state to \`Success\`, \`Emergency\`, or \`Error\`.

\#\#\#\# \[NEW\] \[app\_navigation\_provider.dart\](file:///Users/crb/Documents/TeleMed\_K/lib/core/providers/app\_navigation\_provider.dart)  
\- Listens to \`medical\_session\_provider\` for emergency prompts. If an emergency occurs, it overrides the router to aggressively push the \*\*Urgență\*\* screen.

\---

\#\#\# 4\. Elderly-Centric UI & Screen Overrides

Applying our CC-BY 4.0 UI design system constraints and specific Stitch screen overrides.

\#\#\#\# \[NEW\] \[theme.dart\](file:///Users/crb/Documents/TeleMed\_K/lib/ui/theme/theme.dart)  
\- \*\*Colors:\*\* Deep off-white backgrounds with pure \`\#000000\` text for maximum contrast mode.  
\- \*\*Typography:\*\* Global \`TextTheme\` ensuring minimum \`18sp\` font size across body text.  
\- \*\*Touch Targets:\*\* Reusable wrappers enforcing a minimum of \`64x64 dp\` with generous padding.

\#\#\#\# \[NEW\] \[home\_screen.dart\](file:///Users/crb/Documents/TeleMed\_K/lib/ui/screens/home\_screen.dart)  
\- Massive screen-filling microphone icon. Primary user interaction is just tapping this.  
\- Persistent bottom navigation bar. Max 3 icons (Home, History, Settings).  
\- Specific target size enforcement for the RO/EN toggle and Camera icon at \`64x64 dp\`.

\#\#\#\# \[NEW\] \[confirmation\_screen.dart\](file:///Users/crb/Documents/TeleMed\_K/lib/ui/screens/confirmation\_screen.dart)  
\- Displays the parsed medical session summary.  
\- Applies the override to strictly remove the redundant 'Înapoi la Ecranul Principal' button to avoid cognitive overload.  
\- Red "Nu, anulează" button requires a stark \`2px solid black border\`.

\#\#\#\# \[NEW\] \[emergency\_screen.dart\](file:///Users/crb/Documents/TeleMed\_K/lib/ui/screens/emergency\_screen.dart)  
\- High-priority red state UI indicating a triggered 112 emergency call dispatch sequence based on the AI's symptom detection.

\---

\#\# Verification Plan

\#\#\# Automated Tests  
\- Unit testing Riverpod state triggers: ensure that injecting mock life-threatening JSON from the AI Engine instantly forces state changes that reroute to the Emergency Screen.  
\- Widget tests simulating low visual acuity to verify accessibility bounds (semantic labels, \>64dp touch areas, font scale factors test).

\#\#\# Manual Verification  
\- Deploying the app to a low-end Android device using ADB.  
\- Running TalkBack (Voice Assistant) over the built app to confirm single-axis navigation rules.  
\- Confirming offline resilience by putting the emulator/device in Airplane mode, creating an observation, and verifying it maps to SQLite.  
\- First launch experience: ensuring Wi-Fi prompting triggers and the 2.58 GB weights download accurately into the correct persistent storage.

