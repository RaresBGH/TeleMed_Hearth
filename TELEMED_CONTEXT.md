# TeleMed_K — Project Context for AI Assistant

## What This Is
Flutter telemedicine app for rural Romania. MVP for Dr. Bogheanu's clinic in Brănești, Dâmbovița.
Competition: Kaggle Gemma 4 Good Hackathon — deadline May 18, 2026.
Repo: https://github.com/RaresBGH/TeleMed_K (private)

## Owner
Rareș Bogheanu (RaresBGH) — QA engineer, 20 years experience, owns medical clinic Dr. Bogheanu in Brănești.
NGO provides devices + digital literacy to elderly patients who cannot afford smartphones.

## Hardware
GX10 (ASUS Ascent GX10, ARM64, 128GB unified memory, NVIDIA GB10 Grace Blackwell)
Test device: Google Pixel 9 Pro (16GB RAM, Tensor G4) — USB cable unreliable, use wireless ADB or emulator
Secondary: Google Pixel 6a

## Tech Stack
- Flutter (Dart) — snap install, at /snap/bin/flutter, version 3.44.0 master channel
- Android SDK at ~/Android/Sdk
- New cmdline-tools at ~/Android/Sdk/cmdline-tools/latest2/bin/sdkmanager (version 19.0)
- KVM available at /dev/kvm — emulator CAN work
- Java 17 at /usr/bin/java
- adb at /usr/lib/android-sdk/platform-tools/adb (ARM64 build)
- GitHub Actions CI builds APK (Flutter 3.32.x stable, ubuntu-latest x86_64)
- SSH key configured for GitHub push

## Build Pipeline
- Push to main → GitHub Actions builds debug APK automatically
- APK downloads from Actions artifacts as telemed-debug-apk.zip
- Install: unzip + adb install
- Wireless ADB: pair via Settings→Developer Options→Wireless debugging

## Current App State
### Working
- App launches without crashing
- Navigation: Acasă (home), Istoric, Doctorul Meu tabs
- FHIR engine initializes — mock data loads (Observation, Condition records visible)
- Dr. Adriana Bogheanu shown in Doctorul Meu tab
- Blue branding (#5BA4CF) applied throughout (was green #0D631B)
- 112 emergency dialer wired (url_launcher)
- ConfirmationScreen auto-navigates to home after 5 seconds
- Auth gate: app starts at loginIdentity route

### Broken / Not Implemented
- Login screen body invisible (scroll fix committed but not yet tested on device)
- AI inference: ML Kit GenAI (genai-prompt:1.0.0-beta2) wired but not calling real API
- Audio recording: dummy file path, no real microphone capture
- Camera capture: dummy file path, no real camera
- Video consultation: stub screen (Text widget only)
- OTP sending: no SMS service configured
- Medplum auth: fictional client_id, will 401

## Key Files
- lib/main.dart — entry point, FHIR init, auth gate
- lib/core/providers/app_navigation_provider.dart — routing (starts at loginIdentity)
- lib/ui/screens/login_identity_screen.dart — CNP + phone login (scroll fix applied)
- lib/ui/screens/home_screen.dart — big microphone button
- lib/ui/screens/emergency_screen.dart — 112 dialer (working)
- android/app/src/main/kotlin/.../channels/LiteRtLmChannel.kt — ML Kit GenAI bridge
- android/app/build.gradle.kts — compileSdk=36, ndkVersion=27.0.12077973
- .github/workflows/build-apk.yml — CI pipeline

## Design Assets
Stitch exports at: ~/sovereign-factory/mobile-workspace/stitch_telemed_k/
Each screen has: code.html + screen.png
Screens: autentificare_updated, acas_home, verificare_i_consim_m_nt_updated_label,
  urgen_emergency, confirmare_confirmation, doctorul_meu_my_doctor, istoric_medical_updated,
  sala_de_a_teptare_i_acord_waiting_room_and_consent, consulta_ie_live_live_video,
  conflict_dispoziv_modal, termeni_de_utilizare_updated, politica_de_confiden_ialitate
Logo: ~/sovereign-factory/mobile-workspace/stitch_telemed_k/vitalease_romanian_health/
Brand color: #5BA4CF (medical blue)
App name in Stitch: VitalEase Romanian Health

## Priority Tasks (ordered)
1. Set up Android emulator (KVM available, cmdline-tools v19.0 ready)
2. Test login screen scroll fix — confirm CNP/phone fields visible
3. Wire real microphone capture (record package)
4. Wire real camera capture (image_picker package)
5. Implement ML Kit GenAI real inference call
6. Demo auth bypass (skip OTP for hackathon demo)
7. Video consultation (Jitsi Meet Flutter SDK)
8. Competition video recording

## Competition Requirements
- Working prototype with Gemma 4 on-device AI
- Public GitHub repo
- Demo video showing end-to-end patient flow
- Health track: rural Romania, elderly patients, sovereign data

## Patient Demo Story (for video)
Maria, 72, Brănești, chest pain, no car, hospital 40km away.
Opens TeleMed_K → voice input → Gemma 4 analyzes symptoms on-device →
urgency detected → one tap calls 112 OR books teleconsultation with Dr. Bogheanu.
NGO provides the device itself for patients who cannot afford one.
