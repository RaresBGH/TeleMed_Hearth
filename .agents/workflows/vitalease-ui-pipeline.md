---
description: VitalEase UI Production Pipeline
---

1. **Ingest & Analyze:** Acknowledge the provided Stitch MCP Export. Do not generate UI elements blindly.
2. **Build UI & Enforce Accessibility:** Write the Flutter screen. You MUST enforce deep off-white backgrounds (#F5F5F5), pure black text (#000000), minimum 18sp scalable fonts, and minimum 64x64 dp touch targets.
3. **Wire Logic:** Connect the UI safely to the Riverpod state providers, the local `FhirRepository`, or the `telemedicine_service` as required by the prompt.
4. **Validate:** Run your `lint-and-validate` skill. You are strictly forbidden from proceeding if there are any static analysis errors.
5. **Version Control:** Once error-free, commit and push this specific feature to the remote GitHub repository.
