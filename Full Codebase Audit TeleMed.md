Full Codebase Audit — TeleMed_K (2026-04-24)                                                            
                                                                                                          
  ---                                                                                                     
  1. lib/ — Every Dart File                                                                               
                                                                                                          
  lib/main.dart — Working (with caveat)                                                                   
                                                                                                          
  - Future<void> main() async, calls WidgetsFlutterBinding.ensureInitialized() ✓                          
  - Calls FhirRepository().initialize() before runApp() wrapped in try/catch ✓                            
  - ProviderScope wraps TeleMedApp ✓                                                                      
  - Switch-based router driven by appNavigationProvider — all 9 routes wired ✓                            
  - Caveat: FhirRepository() instantiated directly here is a separate instance from the one created by    
  fhirRepositoryProvider. The initialize() call initialises the native FHIR engine globally (idempotent), 
  which is fine — but any state stored on this instance is discarded.                                     
                                                                                                          
  lib/core/providers/app_navigation_provider.dart — Working                                               
   
  - Starts at AppRoute.loginIdentity ✓ (Phase 1 fix in place)                                             
  - Listens to medicalSessionProvider: emergency→emergency, success→confirmation, idle→home (not
  loginIdentity — after any reset the user bypasses auth)                                                 
  - navigateTo() for manual routing ✓                       
                                                                                                          
  lib/core/providers/auth_provider.dart — Working (thin)                                                  
                                                                                                          
  - LoginCnpNotifier stores CNP string in Riverpod state                                                  
  - Used by LoginVerificationScreen to read CNP for Medplum auth call ✓
                                                                                                          
  lib/core/providers/medical_session_provider.dart — Working (logic correct, inputs dummy)                
                                                                                                          
  - SessionState enum: idle/recording/processing/success/emergency/error ✓                                
  - processAudio() and processMedia() call AI engine, save FHIR resources, handle EmergencyFlagException
  correctly ✓                                                                                             
  - Broken: Both methods receive File('dummy_voice_path.wav') / File('dummy_multimodal_path.jpg') from
  callers — these files don't exist                                                                       
                                                            
  lib/core/providers/my_doctor_provider.dart — Working                                                    
                                                            
  - Two FutureProviders: mostRecentEncounterProvider and mostRecentMedicationProvider                     
  - Read from fhirRepositoryProvider ✓                      
  - Data bug: getMostRecentMedicationRequest() — UI reads data['medicationCodeableConcept']?['text'] but  
  mock data stores coding[0].display not text key → shows "Tratament" fallback always                     
   
  lib/core/providers/patient_history_provider.dart — Working                                              
                                                            
  - patientHistoryProvider FutureProvider backed by fhirRepositoryProvider.getPatientHistory() ✓          
                                                            
  lib/core/services/ai_engine_service.dart — Stub (Dart side structurally correct)                        
                                                            
  - AiEngineService(FhirRepository) — constructor dependency injection ✓                                  
  - evaluateAudio(): fetches patient history for RAG, builds system prompt, invokes
  com.telemed_k/litert_lm channel method evaluateAudio — channel method name mismatch: new Kotlin channel 
  only handles runInference, not evaluateAudio → will throw MissingPluginException at runtime
  - evaluateMedia(): same mismatch — invokes evaluateMedia, not handled by new channel                    
  - EmergencyFlagException with confidence threshold 0.8 ✓                                                
  - downloadWeights() / initializeModel() exist but are never called anywhere in the app                  
                                                                                                          
  lib/core/services/fhir_sync_service.dart — Stub (never started)                                         
                                                                                                          
  - initializeNetworkListener() is never called from anywhere in the app                                  
  - Auth token set correctly via setAuthToken() after successful Medplum login ✓
  - Sync logic (FHIR Transaction Bundle POST) is well-formed ✓                                            
  - Dead: Without initializeNetworkListener() being called, sync never triggers                           
                                                                                                          
  lib/core/services/media_retention_service.dart — Working (never triggered)                              
                                                                                                          
  - uploadMediaToCloud() uploads binary + creates Media FHIR resource ✓                                   
  - executeGarbageCollection() 14-day deletion rule ✓       
  - mediaRetentionServiceProvider exists but is never consumed by any screen                              
                                                            
  lib/core/services/medplum_auth_service.dart — Stub                                                      
                                                            
  - POSTs to https://api.medplum.com/oauth2/token with grant_type: password                               
  - client_id: 'telemed_k_mobile_client' — fictional, no Medplum project configured
  - Will return HTTP 4xx on every real attempt                                                            
  - _smartAuthUri, _smartJwksUri, _redirectUri declared but annotated // ignore: unused_field             
                                                                                                          
  lib/core/services/telemedicine_service.dart — Stub                                                      
                                                                                                          
  - captureFcmToken() → invokes getFcmToken on Kotlin channel → returns stub string                       
  - listenForIncomingCall() sets method call handler ✓      
  - answerCall() → invokes answerCall on Kotlin channel → stub acknowledges only                          
  - telemedicineServiceProvider auto-calls listenForIncomingCall on create ✓                              
                                                                                                          
  lib/data/repositories/fhir_repository.dart — Working (bridge only)                                      
                                                                                                          
  - All methods delegate to com.telemed_k/fhir_engine MethodChannel ✓                                     
  - initialize() + seedMockData() called from main.dart ✓   
  - Full CRUD: saveObservation, saveCondition, getUnsyncedResources, getPatientHistory,                   
  getMostRecentEncounter, getMostRecentMedicationRequest, updateEncounterConsent, markAsSynced ✓          
                                                                                                          
  lib/ui/theme/theme.dart — Working                                                                       
                                                            
  - AppTheme.lightTheme: off-white #F5F5F5 background, pure black text, 22sp/18sp body, 0 elevation AppBar
   ✓                                                        
  - AccessibleTouchTarget: minWidth/minHeight: 64, Semantics(button: true) ✓                              
                                                                                                          
  lib/ui/screens/login_identity_screen.dart — Partial                                                     
                                                                                                          
  - CNP + phone fields with FilteringTextInputFormatter.digitsOnly ✓                                      
  - _showAjutorModal() presents camera/voice options ✓      
  - _extractViaCamera() / _extractViaVoice(): call AI engine with File('dummy_id.jpg') /                  
  File('dummy_voice.wav') — these don't exist, will throw PlatformException caught and shown as snackbar  
  - CONTINUĂ button: saves CNP to provider, navigates to verification ✓                                   
  - Wrapped in SizedBox.expand(child: SingleChildScrollView(...)) ✓ (scroll fix applied)                  
                                                                                                          
  lib/ui/screens/login_verification_screen.dart — Partial                                                 
                                                                                                          
  - 6-digit OTP with focus chain ✓                                                                        
  - smart_auth SMS auto-read via getSmsWithUserConsentApi() ✓ (requires real SMS to arrive)
  - Calls MedplumAuthService.authenticateWithOTP() → will always fail (no real Medplum)                   
  - Legal modals open correctly via LegalDocumentModal ✓                                                  
  - Text bug: Privacy policy modal still references "LiteRT-LM (Gemma 4 E2B)" — stale after ML Kit        
  migration                                                                                               
                                                                                                          
  lib/ui/screens/home_screen.dart — Partial                                                               
                                                            
  - Mic button: startRecording() → processAudio(File('dummy_voice_path.wav')) after 1s — dummy file       
  - Camera icon: startRecording() → processMedia(File('dummy_multimodal_path.jpg')) after 1s — dummy file
  - Session state drives UI (processing → spinner, else → mic button) ✓                                   
  - Language toggle: onTap: () {} — dead                                                                  
  - Bottom nav to History and MyDoctor ✓                                                                  
                                                                                                          
  lib/ui/screens/emergency_screen.dart — Working                                                          
                                                                                                          
  - "SUNĂ ACUM": Uri(scheme: 'tel', path: '112') → canLaunchUrl → launchUrl ✓ (Phase 2 fix)               
  - "Nu, anulează": medicalSessionProvider.reset() → routes back to home ✓
  - url_launcher imported ✓                                                                               
                                                            
  lib/ui/screens/confirmation_screen.dart — Working                                                       
                                                            
  - ConsumerStatefulWidget with 5-second Future.delayed → navigateTo(AppRoute.home) ✓ (Phase 2 fix)       
  - mounted guard ✓                                         
  - Check-circle icon now Color(0xFF5BA4CF) ✓                                                             
                                                                                                          
  lib/ui/screens/history_screen.dart — Working                                                            
                                                                                                          
  - patientHistoryProvider FutureProvider renders list ✓                                                  
  - Item onTap: () {} — no detail screen, tap does nothing
  - Fallback text for Observation/Condition in Romanian ✓                                                 
  - Bottom nav ✓                                                                                          
                                                                                                          
  lib/ui/screens/my_doctor_screen.dart — Partial                                                          
                                                            
  - _initializeTelemedicine() runs on initState ✓                                                         
  - Demo hack: Future.delayed(2s) unconditionally sets _isCallActive = true — incoming call is always
  faked                                                                                                   
  - Doctor name "Dr. Adriana Bogheanu" hardcoded, no avatar image
  - Encounter/medication cards loaded from FHIR ✓ (will show mock data)                                   
  - RĂSPUNDE button → WaitingRoom ✓                                                                       
                                                                                                          
  lib/ui/screens/waiting_room_screen.dart — Partial                                                       
                                                                                                          
  - Consent card UI ✓                                                                                     
  - "Sunt de acord": calls updateEncounterConsent(callId) + answerCall(callId) (both stub) → navigates to
  VideoConsultation ✓                                                                                     
                                                            
  lib/ui/screens/video_consultation_screen.dart — Stub                                                    
                                                            
  - 7 lines. Text('Video Feed Active') on black background. Zero WebRTC.                                  
                                                            
  lib/ui/widgets/device_conflict_modal.dart — Partial                                                     
                                                            
  - Confirm path: debugPrint('Medplum session revoked...') + Navigator push to HomeScreen using           
  MaterialPageRoute — bypasses Riverpod router entirely, creates widget tree inconsistency
  - Cancel: Navigator.pop() ✓                                                                             
  - Never shown by any screen (no trigger exists)           
                                                                                                          
  lib/ui/widgets/legal_document_modal.dart — Working
                                                                                                          
  - Scrollable text with "Înapoi" button ✓                                                                
  - Content is placeholder prose, not real legal text
                                                                                                          
  ---                                                       
  2. android/ — Every Native File                                                                         
                                                            
  android/app/build.gradle.kts — Working
                                                                                                          
  - compileSdk = 36, ndkVersion = "27.0.12077973" ✓                                                       
  - minSdk = 28, Java 17, core library desugaring enabled ✓                                               
  - TODO line 40: // TODO: Add your own signing config for the release build. — debug key used for release
   builds                                                                                                 
  - SQLCipher pickFirsts for multi-ABI .so conflicts ✓                                                    
  - META-INF packaging excludes for FHIR SDK transitive dep conflicts ✓                                   
                                                                                                          
  android/build.gradle.kts — Working                                                                      
                                                                                                          
  - allprojects { repositories { google(); mavenCentral() } } — no custom repos ✓                         
  - Build dir remapped to ../../build for Flutter conventions ✓
                                                                                                          
  android/settings.gradle.kts — Working                     
                                                                                                          
  - Flutter SDK path resolved from local.properties ✓                                                     
  - AGP 8.11.1, Kotlin 2.2.20 ✓
  - pluginManagement.repositories: google, mavenCentral, gradlePluginPortal ✓                             
                                                                                                          
  android/gradle.properties — Working                                                                     
                                                                                                          
  - JVM heap: -Xmx4g -XX:MaxMetaspaceSize=512m ✓                                                          
  - Daemon/parallel/caching all disabled (CI-safe) ✓
  - android.useAndroidX=true, android.enableJetifier=true ✓                                               
                                                            
  android/app/src/main/AndroidManifest.xml — Working                                                      
                                                            
  - 8 <uses-permission> tags: INTERNET, RECORD_AUDIO, CAMERA, READ_MEDIA_IMAGES/VIDEO/AUDIO, CALL_PHONE,  
  VIBRATE ✓                                                 
  - <uses-library android:name="androidx.window.extensions" required="false"/> inside <application> ✓     
  - 3 <queries> blocks: PROCESS_TEXT, DIAL/tel, com.google.android.aicore ✓                               
  - FlutterFragmentActivity (required by smart_auth) ✓                                                    
                                                                                                          
  MainActivity.kt — Working                                                                               
                                                            
  - Registers 3 MethodChannels: fhir_engine, litert_lm, telemedicine ✓                                    
  - Bidirectional telemedicine channel set up via setDartChannel() ✓
                                                                                                          
  channels/FhirEngineChannel.kt — Working (most complete native file)                                     
                                                                                                          
  - Implements all 10 methods: initializeDatabase, saveObservation, saveCondition, getUnsyncedResources,  
  getPatientHistory, getMostRecentEncounter, getMostRecentMedicationRequest, updateEncounterConsent,
  markAsSynced, seedMockData ✓                                                                            
  - Uses real Google Android FHIR SDK: FhirEngineProvider.init(), fhirEngine.create(),
  fhirEngine.search<>() ✓                                                                                 
  - Mock data seeded: Patient (Ion Popescu), Practitioner (Dr. Bogheanu), Observation (BP), Condition
  (hypertension), MedicationRequest (Lisinopril), Encounter (pending-encounter) ✓                         
  - markAsSynced() uses meta tag approach rather than SDK sync state machine — functional but non-standard
   ✓                                                                                                      
                                                            
  channels/LiteRtLmChannel.kt — Stub (ML Kit migration)                                                   
                                                            
  - Handles: isModelReady → true, loadModel → true, runInference → response, dispose → null               
  - Channel method mismatch: Dart side calls evaluateAudio and evaluateMedia; Kotlin only handles
  runInference — these calls will fail at runtime with MissingPluginException                             
  - buildStructuredResponse(): keyword heuristic for Romanian emergency terms (durere, piept, respirat,
  amețeală, leșin) → sets emergency: true, confidence: 0.85 ✓                                             
  - runMlKitInference() is async but calls buildStructuredResponse() — the actual ML Kit SDK call is noted
   as "will be wired to the real API in the next integration step" ✓                                      
                                                            
  channels/TelemedicineChannel.kt — Stub                                                                  
                                                            
  - getFcmToken → returns "fcm-stub-token-telemed-k-${System.currentTimeMillis()}" (no Firebase)          
  - answerCall → logs and returns null (no WebRTC)
  - notifyIncomingCall() method exists for native→Dart push, never called (no FCM)                        
                                                                                                          
  ---                                                                                                     
  3. pubspec.yaml Dependencies                                                                            
                                                                                                          
  ┌───────────────────┬────────────────┬──────────┬───────────────────┬───────────────────────────────┐
  │      Package      │    Version     │ Resolved │       Role        │            Status             │   
  │                   │   constraint   │          │                   │                               │   
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤
  │ flutter           │ sdk            │ —        │ Framework         │ ✓                             │   
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤
  │ cupertino_icons   │ ^1.0.8         │ 1.0.9    │ iOS icons         │ ✓                             │   
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤
  │ flutter_riverpod  │ ^3.3.1         │ 3.3.1    │ State management  │ ✓ Used everywhere             │   
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤
  │ connectivity_plus │ ^7.1.0         │ 7.1.0    │ Network check for │ ✓ Used in FhirSyncService     │   
  │                   │                │          │  sync             │                               │
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤   
  │ smart_auth        │ ^3.2.0         │ 3.2.0    │ SMS OTP auto-read │ ✓ Used in verification screen │
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤   
  │ http              │ ^1.6.0         │ 1.6.0    │ Medplum REST      │ ✓ Used in sync/auth/media     │
  │                   │                │          │ calls             │ services                      │   
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤   
  │ path_provider     │ ^2.1.5         │ 2.1.5    │ Local file paths  │ ✓ Used in media retention     │
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤   
  │ url_launcher      │ ^6.3.0         │ 6.3.2    │ 112 tel: dialer   │ ✓ Used in emergency screen    │   
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤
  │ flutter_local_ai  │ ^0.0.4         │ resolved │ Local AI wrapper  │ ⚠ Added but not imported or   │   
  │                   │                │          │                   │ used anywhere                 │
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤   
  │ flutter_test      │ sdk            │ —        │ Test framework    │ ✓                             │
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤   
  │ mockito           │ ^5.4.6         │ 5.4.6    │ Test mocking      │ ✓ Used in tests               │
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤
  │ flutter_lints     │ ^4.0.0         │ 4.0.0    │ Lint rules        │ ✓                             │   
  ├───────────────────┼────────────────┼──────────┼───────────────────┼───────────────────────────────┤
  │ integration_test  │ sdk            │ —        │ Integration tests │ Directory exists, tests not   │   
  │                   │                │          │                   │ written                       │
  └───────────────────┴────────────────┴──────────┴───────────────────┴───────────────────────────────┘   
                                                            
  ---                                                                                                     
  4. ML Kit / LiteRT-LM Integration — What Exists vs Stub   
                                                                                                          
  What was removed: com.google.ai.edge.litertlm:litertlm-android:0.9.0-alpha01 — unresolvable alpha
  artifact                                                                                                
                                                            
  What was added:                                                                                         
  - com.google.mlkit:genai-prompt:1.0.0-beta2 — in build.gradle.kts ✓
  - com.google.android.gms:play-services-tasks:18.2.0 ✓                                                   
  - AICore package query in manifest ✓                 
  - flutter_local_ai: ^0.0.4 in pubspec ✓                                                                 
                                                            
  What is actually wired: Nothing. The inference path is:                                                 
                                                                                                          
  Dart: evaluateAudio() → MethodChannel('litert_lm').invokeMethod('evaluateAudio')                        
                                                           ↓                                              
  Kotlin: onMethodCall() → when("evaluateAudio") → MISSING → result.notImplemented()
                                                                                                          
  The Dart calls evaluateAudio/evaluateMedia; the Kotlin channel only handles runInference. This is a     
  broken contract — every AI triage call will fail silently or throw. The fix requires either updating the
   Dart service to call runInference or adding the old method names back to the Kotlin channel.           
                                                            
  LiteRtLmChannel.runMlKitInference() calls buildStructuredResponse() which is a keyword heuristic, not an
   ML Kit SDK call. The actual GenerativeModel API is not instantiated anywhere.
                                                                                                          
  ---                                                       
  5. Audio Recording — Real or Dummy?
                                                                                                          
  Dummy. There is no audio recording package in pubspec.yaml (record, flutter_sound, just_audio — none
  present). Every audio path in the app passes a literal File('dummy_voice_path.wav') or                  
  File('dummy_voice.wav') to the AI engine. These files do not exist on the device. The Kotlin channel
  will return FILE_NOT_FOUND error, caught by the Dart catch block, shown as a snackbar.                  
                                                            
  Affected locations:
  - home_screen.dart:61 — File('dummy_voice_path.wav')
  - login_identity_screen.dart:128 — File('dummy_voice.wav')                                              
  
  ---                                                                                                     
  6. Camera Implementation — Real or Dummy?                 
                                                                                                          
  Dummy. No camera package (camera, image_picker, camera_platform_interface) in pubspec.yaml. Every camera
   path passes a literal File('dummy_multimodal_path.jpg') or File('dummy_id.jpg').                       
  
  Affected locations:                                                                                     
  - home_screen.dart:37 — File('dummy_multimodal_path.jpg') 
  - login_identity_screen.dart:103 — File('dummy_id.jpg')                                                 
  
  ---                                                                                                     
  7. Auth Flow — What Is Bypassed, What Is Real             
                                                                                                          
  ┌─────────────────────────────────────────┬───────────┬────────────────────────────────────────────┐ 
  │                  Step                   │  Status   │                   Detail                   │    
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤ 
  │ App opens → LoginIdentity               │ ✓ Real    │ AppRoute.loginIdentity is initial route    │    
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤ 
  │ CNP entry with                          │ ✓ Real UI │ Validation: only checks cnp.isNotEmpty, no │    
  │ FilteringTextInputFormatter.digitsOnly  │           │  length/checksum check                     │    
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤    
  │ CNP saved to loginCnpProvider           │ ✓ Real    │ Riverpod state ✓                           │    
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤    
  │ Navigation to LoginVerification         │ ✓ Real    │ navigateTo(AppRoute.loginVerification) ✓   │ 
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤    
  │ SMS OTP auto-read via smart_auth        │ ✓ Real    │ Requires actual SMS arriving from a real   │ 
  │                                         │ mechanism │ sender                                     │    
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤ 
  │ OTP submitted to Medplum oauth2/token   │ ✗ Broken  │ client_id: 'telemed_k_mobile_client'       │    
  │                                         │           │ doesn't exist on Medplum                   │    
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤ 
  │ On auth failure → snackbar              │ ✓ Real    │ User sees "Cod invalid sau eroare de       │    
  │                                         │           │ rețea"                                     │    
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤ 
  │ On auth success → AppRoute.home         │ ✓ Real    │ But success never happens in current state │    
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤    
  │ FhirSyncService.setAuthToken()          │ ✓ Real    │ Token stored; initializeNetworkListener()  │ 
  │                                         │           │ never called so sync never fires           │    
  ├─────────────────────────────────────────┼───────────┼────────────────────────────────────────────┤    
  │ Bypass: After any session reset         │ ⚠         │ SessionState.idle → AppRoute.home skips    │
  │                                         │           │ login entirely                             │    
  └─────────────────────────────────────────┴───────────┴────────────────────────────────────────────┘
                                                                                                          
  ---                                                       
  8. TODOs, FIXMEs, Stubs — Complete List
                                                                                                          
  Dart (lib/):
                                                                                                          
  ┌────────────────────────────────┬─────────┬────────────────────────────────────────────────────────┐ 
  │              File              │  Line   │                        Content                         │   
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤ 
  │ home_screen.dart               │ 35, 59  │ // Mocking a multimodal/audio processing flow wait     │ 
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤ 
  │ home_screen.dart               │ 37, 61  │ File('dummy_multimodal_path.jpg'),                     │   
  │                                │         │ File('dummy_voice_path.wav')                           │   
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤   
  │ login_identity_screen.dart     │ 102–103 │ // Dummy visual file, File('dummy_id.jpg')             │   
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤ 
  │ login_identity_screen.dart     │ 127–128 │ // Dummy audio file, File('dummy_voice.wav')           │   
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤ 
  │ login_identity_screen.dart     │ 27      │ Language toggle onTap: () {}                           │ 
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤   
  │ medplum_auth_service.dart      │ 13      │ // SMART-on-FHIR Configuration Placeholders            │ 
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤   
  │ login_verification_screen.dart │ 260,    │ Legal text strings start with "Placeholder pentru..."  │
  │                                │ 285     │                                                        │   
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤
  │ login_verification_screen.dart │ 285     │ Privacy policy still mentions "LiteRT-LM (Gemma 4      │   
  │                                │         │ E2B)" — stale                                          │   
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤
  │ my_doctor_screen.dart          │ 47      │ // Mock incoming call for demo purposes after 2        │   
  │                                │         │ seconds                                                │   
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤
  │ my_doctor_screen.dart          │ 114     │ // Placeholder for real image                          │   
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤
  │ device_conflict_modal.dart     │ 11      │ // Placeholder Medplum session revocation              │
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤   
  │ fhir_repository.dart           │ 21      │ // Seed mock data upon first launch (Phase 7.7)        │
  ├────────────────────────────────┼─────────┼────────────────────────────────────────────────────────┤   
  │ history_screen.dart            │ 85      │ Item onTap: () {} — no detail screen                   │
  └────────────────────────────────┴─────────┴────────────────────────────────────────────────────────┘   
                                                            
  Android (android/):                                                                                     
                                                            
  ┌────────────────────────┬────────┬──────────────────────────────────────────────────────────────────┐  
  │          File          │  Line  │                             Content                              │
  ├────────────────────────┼────────┼──────────────────────────────────────────────────────────────────┤  
  │ build.gradle.kts       │ 40     │ // TODO: Add your own signing config for the release build.      │
  ├────────────────────────┼────────┼──────────────────────────────────────────────────────────────────┤
  │ LiteRtLmChannel.kt     │ 62     │ // and will be wired to the real API in the next integration     │
  │                        │        │ step.                                                            │  
  ├────────────────────────┼────────┼──────────────────────────────────────────────────────────────────┤
  │ TelemedicineChannel.kt │ 70–74  │ FCM stub token                                                   │  
  │                        │        │ "fcm-stub-token-telemed-k-${System.currentTimeMillis()}"         │
  ├────────────────────────┼────────┼──────────────────────────────────────────────────────────────────┤  
  │ TelemedicineChannel.kt │ 91–101 │ WebRTC answerCall stub — logs only                               │
  └────────────────────────┴────────┴──────────────────────────────────────────────────────────────────┘  
  
  ---                                                                                                     
  9. GitHub Actions CI Pipeline                             
                                                                                                          
  Trigger: Push to main branch only. No PR checks, no scheduled runs.
                                                                                                          
  Runner: ubuntu-latest (x86_64) — correct for AAPT2.                                                     
                                                                                                          
  Steps in order:                                                                                         
  1. actions/checkout@v4 — full repo checkout               
  2. actions/setup-java@v4 — Eclipse Temurin JDK 17                                                       
  3. subosito/flutter-action@v2 — Flutter 3.32.x stable, SDK cached
  4. flutter pub get — resolves Dart deps                                                                 
  5. flutter build apk --debug --no-shrink — debug APK, R8/ProGuard disabled                              
    - GRADLE_OPTS: "-Xmx4g -XX:MaxMetaspaceSize=512m" ✓                                                   
    - android/gradle.properties also sets -Xmx4g for daemon (both aligned) ✓                              
  6. actions/upload-artifact@v4 — uploads build/app/outputs/flutter-apk/app-debug.apk as                  
  telemed-debug-apk, 7-day retention                                                                      
                                                                                                          
  What it produces: A debug APK signed with the debug keystore. The APK will install on Android 9+ (minSdk
   28) devices.                                                                                           
                                                            
  What it does NOT do:                                                                                    
  - No test step (flutter test) — the unit tests that exist are never run in CI
  - No flutter analyze step — lints not enforced                                                          
  - No release signing                                      
  - No deployment to Play Store or Firebase App Distribution                                              
  - No matrix build across Flutter versions                 
  - Build will currently fail at Gradle sync if com.google.mlkit:genai-prompt:1.0.0-beta2 is not          
  resolvable from google() or mavenCentral() — this is the remaining highest-risk dependency (beta channel
   artifact, availability unconfirmed) 
