# The North Star Directive
Our ultimate end goal is to create a perfect telemedicine app for rural areas lacking medical coverage. Every architectural decision, UI prompt, and generated code block must prioritize extreme accessibility for the elderly, offline-first resilience for spotty networks, and strict medical data compliance.

# 1. Operational Rules
- Do NOT run or test autonomously.
- Ask before making architectural changes.
- Commit to GitHub after each completed feature.

# 2. Architectural & Data Constraints
- All medical data must be structured strictly as HL7 FHIR Observation/Condition resources.
- The local database must be an encrypted SQLite database utilizing the Google Android FHIR SDK.
- AI processing must utilize the Gemma 4 E2B model running locally via LiteRT-LM.
- Licensing: All generated code must be explicitly licensed and documented under CC-BY 4.0 to comply with The Gemma 4 Good Hackathon rules.

# 3. Elderly-Centric UI/UX Rules
- **Typography:** Minimum baseline font size of 18sp/dp, dynamically scalable.
- **Touch Targets:** Minimum touch target size of 48x48 dp (preferably 64x64 dp) separated by generous whitespace.
- **Contrast:** Pure black text on soft off-white backgrounds (Strict WCAG AAA).
- **Navigation:** Single-axis navigation only. No complex nested menus or hamburger menus. Use a persistent bottom navigation bar with a maximum of three core icons.
- **Voice-First Modality:** The primary interaction must be a massive, screen-filling microphone icon that triggers on-device audio-to-text processing. Keyboards should be hidden by default.

**# 4. Sub-Agent & Context Purity Rules**
- **The "One Task, One Message" Rule:** Never combine multiple architectural changes into a single output. Execute tasks sequentially to maintain context window purity.
- **Sub-Agent Orchestration:** When building distinct features, you must utilize the sub-agent feature to spin up parallel agents with fresh context windows to avoid context rot.

**# 5. Multimodal & Backend Purity**
- **Native Multimodality:** Rely exclusively on Gemma 4's native multimodal capabilities to process text, image, audio, and video inputs locally via LiteRT-LM. Do NOT integrate third-party APIs for transcription (STT) or Optical Character Recognition (OCR).
- **The Medplum Backend Bridge:** The application syncs strictly with Medplum as the open-source, FHIR-native Electronic Health Record (EHR) backend. Do NOT build custom backend web portals or proprietary database schemas.

**# 6. Vibe Coding Diagnostics**
- If you find yourself stuck in a loop or your performance degrades, you must stop immediately, explain succinctly how you are going to solve the problem, and state exactly what will be different this time compared to the previous attempt.

UI STRICT RULE: Never generate frontend Flutter screens from scratch. You must always wait for the user to provide a Stitch MCP Export before writing UI code.