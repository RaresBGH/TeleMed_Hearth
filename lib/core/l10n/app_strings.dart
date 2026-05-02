// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

/// Centralized bilingual string table.
///
/// Usage in build():
///   final lang = ref.watch(languageProvider);
///   Text(AppStrings.of(lang, 'home.subtitle'))
///
/// The widget rebuilds automatically when languageProvider changes because
/// ref.watch() is called in the build method that reads lang.
class AppStrings {
  AppStrings._();

  // ── Romanian strings (default) ────────────────────────────────────────────
  static const _ro = <String, String>{
    // ── Home ──────────────────────────────────────────────────────────────
    'home.greeting_default':  'Bună ziua!',
    'home.subtitle':          'Cum vă simțiți astăzi?',
    'home.ai_ready':          'AI pregătit',
    'home.ai_loading':        'AI se încarcă...',
    'home.voice_title':       'Descrieți prin voce',
    'home.voice_subtitle':    'Apăsați și vorbiți despre simptome',
    'home.voice_recording':   'Înregistrare activă...',
    'home.voice_stop':        'Apăsați din nou pentru a opri',
    'home.photo_title':       'Trimiteți o fotografie',
    'home.photo_subtitle':    'Fotografiați zona afectată',
    'home.text_title':        'Scrieți un mesaj',
    'home.text_subtitle':     'Descrieți în scris simptomele',
    'home.emergency_title':   'Urgență 112',
    'home.emergency_subtitle':'Apelați serviciul de urgență',
    'home.emergency_label':   'Urgență 112 — Apelați serviciul de urgență',
    'home.processing':        'Asistentul analizează...',
    'home.dialog_title':      'Descrieți simptomele',
    'home.dialog_hint':       'Scrieți simptomele dumneavoastră...',
    'home.dialog_cancel':     'Anulează',
    'home.dialog_send':       'TRIMITE',
    'home.mic_error':         'Nu s-a putut porni înregistrarea:',
    'home.mic_stop_error':    'Eroare la oprirea înregistrării.',
    'home.mic_no_perm':       'Permisiunea pentru microfon este necesară.',
    'home.cam_no_perm':       'Permisiunea pentru cameră este necesară.',

    // ── History / Dosar Medical ────────────────────────────────────────────
    'history.title':          'Dosar Medical',
    'history.subtitle':       'Consultați rapoartele trimise anterior.',
    'history.empty':          'Nu există istoric medical.',
    'history.error':          'Eroare la încărcarea istoricului.',
    'history.ai_label':       'Răspuns inițial AI',
    'history.conv_label':     'Conversație',
    'history.continue_btn':   'Continuă conversația',
    'history.no_content':     'Nu există conținut detaliat pentru acest raport.',
    'history.dialog_saved':   'Dialog Salvat',
    'history.triage_ai':      'Triaj AI',
    'history.report':         'Raport',
    'history.open_details':   'Deschide detalii raport',

    // ── Doctor / Medic ─────────────────────────────────────────────────────
    'doctor.screen_title':    'Medicul Meu',
    'doctor.available':       'Disponibil acum',
    'doctor.incoming_call':   'Apel Video de la Dr. Bogheanu',
    'doctor.scheduled':       'Consultație programată',
    'doctor.answer':          'RĂSPUNDE',
    'doctor.decline':         'Respinge apelul',
    'doctor.last_visit':      'Ultima consultație',
    'doctor.none':            'Niciuna',
    'doctor.prescription':    'Rețetă activă',
    'doctor.treatment':       'Tratament',
    'doctor.error':           'Eroare',
    'doctor.answer_sem':      'Răspunde la apel',
    'doctor.decline_sem':     'Respinge apelul',
    'doctor.unknown_date':    'Necunoscută',
    'doctor.name':            'Dr. Bogheanu',

    // ── Login identity ────────────────────────────────────────────────────
    'login.appbar':           'Autentificare',
    'login.title':            'Sănătatea ta,\nla un click distanță',
    'login.cnp_label':        'CNP (Cod Numeric Personal)',
    'login.cnp_hint':         'Introduceți cele 13 cifre',
    'login.phone_label':      'Număr de Telefon',
    'login.phone_hint':       'Ex: 0722 000 000',
    'login.continue_btn':     'CONTINUĂ',
    'login.continue_sem':     'Continuă autentificarea',
    'login.help_btn':         'Ajutor',
    'login.help_sem':         'Deschide meniu ajutor',
    'login.age_error':        'Vârsta minimă este 18 ani.',
    'login.phone_error':      'Număr de telefon invalid. Format: 07XXXXXXXX',
    'login.help_title':       'Ajutor Multimodal',
    'login.help_desc':        'Alegeți metoda preferată de a completa datele:',
    'login.camera_btn':       'Cameră (Buletin)',
    'login.voice_btn':        'Voce',
    'login.camera_sem':       'Folosește Camera pentru Buletin',
    'login.voice_sem':        'Folosește Vocea',
    'login.info_text':        'Dacă aveți nevoie de ajutor, apăsați butonul de Ajutor de mai jos. Câmpurile pot fi completate audio sau prin fotografierea actului de identitate.',
    'login.otp_sent':         'Codul de verificare a fost trimis la numărul asociat CNP-ului dumneavoastră. Introduceți codul primit.',
    'login.voice_listening':  'Vorbiți acum… (8 secunde)',
    'login.voice_no_data':    'Nu am putut extrage datele. Vă rugăm completați manual.',
    'login.cam_error':        'Eroare cameră:',
    'login.voice_error':      'Eroare voce:',

    // ── OTP verification ──────────────────────────────────────────────────
    'otp.title':              'Verificare',
    'otp.subtitle':           'Introduceți codul din 6 cifre primit prin SMS',
    'otp.confirm_btn':        'SUNT DE ACORD CU TERMENII - CREEAZĂ CONT',
    'otp.resend':             'Nu ați primit codul? Trimite din nou',
    'otp.locked_msg':         'Prea multe încercări. Contactați clinica.',
    'otp.wrong_code':         'Cod incorect. Vă rugăm încercați din nou.',
    'otp.security_text':      'Siguranța datelor dumneavoastră este prioritatea noastră. Prin acest cod, confirmăm identitatea dumneavoastră pentru a vă proteja dosarul medical.',
    'otp.demo_hint':          'Mod demonstrativ: codul este format din ultimele 6 cifre ale CNP-ului (ex: CNP 1850415150017 → cod 150017)',
    'otp.terms_btn':          '📖 Termeni de Utilizare',
    'otp.privacy_btn':        '🔒 Politica de Confidențialitate',
    'otp.terms_title':        'Termeni de Utilizare',
    'otp.privacy_title':      'Politica de Confidențialitate',

    // ── Chat / Medical response ────────────────────────────────────────────
    'chat.followup_prompt':   'Aveți și alte simptome pe care doriți să le descrieți?',
    'chat.appbar_title':      'Asistentul tău medical',
    'chat.section_label':     'Analiza simptomelor',
    'chat.default_response':  'Simptomele dumneavoastră au fost înregistrate.',
    'chat.divider_label':     'CONTINUAȚI CONVERSAȚIA',
    'chat.finalize_btn':      'Finalizează Dialogul',
    'chat.saved_snack':       'Dialogul a fost salvat în dosarul medical',
    'chat.save_error':        'Eroare la salvare:',
    'chat.voice_bubble':      '🎤 Mesaj vocal',
    'chat.photo_bubble':      '📷 Fotografie',
    'chat.hint':              'Scrieți sau vorbiți...',
    'chat.analyzing_photo':   'Se analizează fotografia...',
    'chat.no_understand':     'Nu am înțeles. Vă rog reformulați.',
    'chat.priority_normal':   'Prioritate normală',
    'chat.emergency_chip':    'URGENȚĂ - Sunați 112',
    'chat.back_title':        'Ieșire din conversație',
    'chat.back_content':      'Doriți să salvați conversația înainte de a ieși?',
    'chat.back_exit':         'Ieși fără a salva',
    'chat.mic_no_perm':       'Permisiunea pentru microfon este necesară.',
    'chat.cam_no_perm':       'Permisiunea pentru cameră este necesară.',
    'chat.voice_sem_rec':     'Se descarcă modelul AI, vă rugăm așteptați',
    'chat.downloading_sem':   'Se descarcă modelul AI, vă rugăm așteptați',
    'chat.error_sem':         'Încearcă din nou descărcarea modelului AI',
    'chat.download_sem':      'Descarcă modelul AI pe dispozitiv',

    // ── Model download ────────────────────────────────────────────────────
    'download.title':         'Pregătim asistentul medical',
    'download.subtitle':      'Se descarcă asistentul virtual. Aceasta este o operațiune ce va avea loc o singură dată, la crearea contului.',
    'download.size_hint':     'Dimensiune: ~2.4 GB',
    'download.wifi_ok':       'WiFi activ — descărcarea este sigură',
    'download.mobile_data':   'Descărcare prin date mobile - pot fi aplicate costuri',
    'download.no_conn':       'Fără conexiune la internet',
    'download.lost_conn':     'Conexiune pierdută în timpul descărcării',
    'download.btn_now':       'DESCARCĂ ACUM',
    'download.btn_retry':     'ÎNCEARCĂ DIN NOU',
    'download.btn_progress':  'SE DESCARCĂ...',
    'download.progress_pct':  'descărcat',
    'download.fail_msg':      'Descărcarea a eșuat. Verificați conexiunea WiFi și încercați din nou.',
    'download.fail_reason':   'Descărcarea a eșuat (%s). Verificați conexiunea WiFi și încercați din nou.',

    // ── Profile completion ─────────────────────────────────────────────────
    'profile.appbar_title':   'Completați profilul',
    'profile.heading':        'Creăm contul dumneavoastră',
    'profile.desc':           'Completați datele de mai jos pentru a vă crea dosarul medical.',
    'profile.first_name':     'Prenume',
    'profile.first_hint':     'Ex: Maria',
    'profile.last_name':      'Nume de familie',
    'profile.last_hint':      'Ex: Ionescu',
    'profile.phone':          'Număr de Telefon',
    'profile.phone_hint':     'Ex: 0722 000 000',
    'profile.continue_btn':   'CONTINUĂ',
    'profile.continue_sem':   'Salvează profilul și continuă',
    'profile.save_error':     'Eroare la salvare. Vă rugăm încercați din nou.',

    // ── Emergency ─────────────────────────────────────────────────────────
    'emergency.title':        'Urgență Medicală Detectată!',
    'emergency.subtitle':     'Apelăm 112 în 10 secunde...',
    'emergency.call_btn':     'SUNĂ ACUM',
    'emergency.cancel_btn':   'Nu, anulează',
    'emergency.call_sem':     'Suna acum la 112',
    'emergency.cancel_sem':   'Anulează apelul de urgență',

    // ── Confirmation ──────────────────────────────────────────────────────
    'confirm.title':          'Consultația a fost salvată cu succes.',
    'confirm.subtitle':       'Datele au fost înregistrate sigur în dosarul local.',
    'confirm.ai_label':       'Răspuns asistent AI',

    // ── Waiting room ──────────────────────────────────────────────────────
    'waiting.connecting':     'Conectare la cabinetul Dr. Bogheanu...',
    'waiting.consent_title':  'Acord de Consultanță',
    'waiting.consent_text':   'Prin acest serviciu, sunteți de acord cu partajarea datelor medicale cu Dr. Bogheanu pentru consultanță de la distanță.',
    'waiting.consent_1':      'Acces securizat la istoricul dumneavoastră medical.',
    'waiting.consent_2':      'Înregistrarea sesiunii pentru acuratețe clinică.',
    'waiting.consent_3':      'Confidențialitate garantată prin protocol medical.',
    'waiting.info':           'Vă rugăm să citiți înainte de a începe.',
    'waiting.agree_btn':      'Sunt de acord',
    'waiting.cancel_btn':     'ANULEAZĂ',
    'waiting.note':           'Consultul va începe imediat după ce apăsați butonul de confirmare.',
    'waiting.agree_sem':      'Sunt de acord cu consultanța',
    'waiting.cancel_sem':     'Anulează apelul',
    'waiting.conn_error':     'Eroare conexiune:',
    'waiting.clinic':         'Cabinetul Medical',

    // ── Video consultation ────────────────────────────────────────────────
    'video.header':           'CONSULTĂ DR. BOGHEANU',
    'video.connecting':       'Se conectează...',
    'video.you_label':        'TU',
    'video.muted':            'Mut',
    'video.unmuted':          'Sunet',
    'video.end_call':         'Închide',
    'video.chat_hint':        'Mesaj sau document...',
    'video.chat_soon':        'Chat și documente — în curând',
    'video.mute_sem':         'Dezactivează microfonul',
    'video.unmute_sem':       'Activează microfonul',
    'video.end_sem':          'Închide consultația',
    'video.chat_sem':         'Deschide chat și documente',

    // ── Dashboard ─────────────────────────────────────────────────────────
    'dashboard.greeting_small':   'Bună ziua,',
    'dashboard.health_title':     'Starea ta de sănătate',
    'dashboard.no_condition':     'Nicio condiție înregistrată',
    'dashboard.last_dialog':      'Ultimul dialog:',
    'dashboard.no_dialog':        'Niciun dialog anterior',
    'dashboard.doctor_label':     'Medicul tău:',
    'dashboard.doctor_name':      'Dr. Adriana Bogheanu',
    'dashboard.next_appt':        'Următoarea programare',
    'dashboard.no_appt':          'Nicio programare',
    'dashboard.active_treatment': 'Tratament activ',
    'dashboard.no_treatment':     'Niciun tratament',
    'dashboard.recent_activity':  'Activitate recentă',
    'dashboard.triage_dialog':    'Dialog Triaj AI',
    'dashboard.no_activity':      'Nicio activitate recentă',
    'dashboard.priority_normal':  'Prioritate normală',
    'dashboard.priority_urgent':  'Urgent',
    'dashboard.cta_btn':          '+ Înregistrează o problemă nouă',

    // ── Shared / nav ──────────────────────────────────────────────────────
    'nav.home':               'Acasă',
    'nav.history':            'Dosar Medical',
    'nav.doctor':             'Medic',
    'lang.switch_sem':        'Schimbă Limba / Change Language',
  };

  // ── English strings ───────────────────────────────────────────────────────
  static const _en = <String, String>{
    // ── Home ──────────────────────────────────────────────────────────────
    'home.greeting_default':  'Good day!',
    'home.subtitle':          'How do you feel today?',
    'home.ai_ready':          'AI ready',
    'home.ai_loading':        'AI loading...',
    'home.voice_title':       'Describe by voice',
    'home.voice_subtitle':    'Tap and speak about your symptoms',
    'home.voice_recording':   'Recording active...',
    'home.voice_stop':        'Tap again to stop',
    'home.photo_title':       'Send a photo',
    'home.photo_subtitle':    'Photograph the affected area',
    'home.text_title':        'Write a message',
    'home.text_subtitle':     'Describe your symptoms in writing',
    'home.emergency_title':   'Emergency 112',
    'home.emergency_subtitle':'Call emergency services',
    'home.emergency_label':   'Emergency 112 — Call emergency services',
    'home.processing':        'Assistant is analyzing...',
    'home.dialog_title':      'Describe your symptoms',
    'home.dialog_hint':       'Write your symptoms here...',
    'home.dialog_cancel':     'Cancel',
    'home.dialog_send':       'SEND',
    'home.mic_error':         'Could not start recording:',
    'home.mic_stop_error':    'Error stopping the recording.',
    'home.mic_no_perm':       'Microphone permission is required.',
    'home.cam_no_perm':       'Camera permission is required.',

    // ── History / Dosar Medical ────────────────────────────────────────────
    'history.title':          'Medical Record',
    'history.subtitle':       'View your previously submitted reports.',
    'history.empty':          'No medical history.',
    'history.error':          'Error loading history.',
    'history.ai_label':       'Initial AI Response',
    'history.conv_label':     'Conversation',
    'history.continue_btn':   'Continue conversation',
    'history.no_content':     'No detailed content for this report.',
    'history.dialog_saved':   'Saved Dialog',
    'history.triage_ai':      'AI Triage',
    'history.report':         'Report',
    'history.open_details':   'Open report details',

    // ── Doctor / Medic ─────────────────────────────────────────────────────
    'doctor.screen_title':    'My Doctor',
    'doctor.available':       'Available now',
    'doctor.incoming_call':   'Video Call from Dr. Bogheanu',
    'doctor.scheduled':       'Scheduled consultation',
    'doctor.answer':          'ANSWER',
    'doctor.decline':         'Decline call',
    'doctor.last_visit':      'Last consultation',
    'doctor.none':            'None',
    'doctor.prescription':    'Active prescription',
    'doctor.treatment':       'Treatment',
    'doctor.error':           'Error',
    'doctor.answer_sem':      'Answer the call',
    'doctor.decline_sem':     'Decline the call',
    'doctor.unknown_date':    'Unknown',
    'doctor.name':            'Dr. Bogheanu',

    // ── Login identity ────────────────────────────────────────────────────
    'login.appbar':           'Sign In',
    'login.title':            'Your health,\none click away',
    'login.cnp_label':        'CNP (Personal Identification Number)',
    'login.cnp_hint':         'Enter 13 digits',
    'login.phone_label':      'Phone Number',
    'login.phone_hint':       'Ex: 0722 000 000',
    'login.continue_btn':     'CONTINUE',
    'login.continue_sem':     'Continue authentication',
    'login.help_btn':         'Help',
    'login.help_sem':         'Open help menu',
    'login.age_error':        'Minimum age is 18 years.',
    'login.phone_error':      'Invalid phone number. Format: 07XXXXXXXX',
    'login.help_title':       'Multimodal Help',
    'login.help_desc':        'Choose your preferred method to fill in the data:',
    'login.camera_btn':       'Camera (ID Card)',
    'login.voice_btn':        'Voice',
    'login.camera_sem':       'Use Camera for ID',
    'login.voice_sem':        'Use Voice',
    'login.info_text':        'If you need help, press the Help button below. Fields can be filled by voice or by photographing your ID document.',
    'login.otp_sent':         'A verification code has been sent to the number associated with your CNP. Enter the code received.',
    'login.voice_listening':  'Speak now… (8 seconds)',
    'login.voice_no_data':    'Could not extract data. Please fill in manually.',
    'login.cam_error':        'Camera error:',
    'login.voice_error':      'Voice error:',

    // ── OTP verification ──────────────────────────────────────────────────
    'otp.title':              'Verification',
    'otp.subtitle':           'Enter the 6-digit code received by SMS',
    'otp.confirm_btn':        'I AGREE TO TERMS — CREATE ACCOUNT',
    'otp.resend':             "Didn't receive the code? Resend",
    'otp.locked_msg':         'Too many attempts. Please contact the clinic.',
    'otp.wrong_code':         'Wrong code. Please try again.',
    'otp.security_text':      'The security of your data is our priority. With this code, we confirm your identity to protect your medical record.',
    'otp.demo_hint':          'Demo mode: the code is the last 6 digits of the CNP (e.g. CNP 1850415150017 → code 150017)',
    'otp.terms_btn':          '📖 Terms of Use',
    'otp.privacy_btn':        '🔒 Privacy Policy',
    'otp.terms_title':        'Terms of Use',
    'otp.privacy_title':      'Privacy Policy',

    // ── Chat / Medical response ────────────────────────────────────────────
    'chat.followup_prompt':   'Do you have any other symptoms you would like to describe?',
    'chat.appbar_title':      'Your medical assistant',
    'chat.section_label':     'Symptom analysis',
    'chat.default_response':  'Your symptoms have been recorded.',
    'chat.divider_label':     'CONTINUE THE CONVERSATION',
    'chat.finalize_btn':      'Finalize Dialog',
    'chat.saved_snack':       'Dialog saved to medical record',
    'chat.save_error':        'Save error:',
    'chat.voice_bubble':      '🎤 Voice message',
    'chat.photo_bubble':      '📷 Photo',
    'chat.hint':              'Write or speak...',
    'chat.analyzing_photo':   'Analyzing photo...',
    'chat.no_understand':     "I didn't understand. Please rephrase.",
    'chat.priority_normal':   'Normal priority',
    'chat.emergency_chip':    'EMERGENCY - Call 112',
    'chat.back_title':        'Exit conversation',
    'chat.back_content':      'Do you want to save the conversation before exiting?',
    'chat.back_exit':         'Exit without saving',
    'chat.mic_no_perm':       'Microphone permission is required.',
    'chat.cam_no_perm':       'Camera permission is required.',
    'chat.voice_sem_rec':     'Downloading AI model, please wait',
    'chat.downloading_sem':   'Downloading AI model, please wait',
    'chat.error_sem':         'Retry downloading the AI model',
    'chat.download_sem':      'Download AI model to device',

    // ── Model download ────────────────────────────────────────────────────
    'download.title':         'Preparing your medical assistant',
    'download.subtitle':      'Downloading the virtual assistant. This is a one-time operation during account creation.',
    'download.size_hint':     'Size: ~2.4 GB',
    'download.wifi_ok':       'WiFi active — download is safe',
    'download.mobile_data':   'Downloading via mobile data — charges may apply',
    'download.no_conn':       'No internet connection',
    'download.lost_conn':     'Connection lost during download',
    'download.btn_now':       'DOWNLOAD NOW',
    'download.btn_retry':     'TRY AGAIN',
    'download.btn_progress':  'DOWNLOADING...',
    'download.progress_pct':  'downloaded',
    'download.fail_msg':      'Download failed. Please check your WiFi and try again.',
    'download.fail_reason':   'Download failed (%s). Please check your WiFi and try again.',

    // ── Profile completion ─────────────────────────────────────────────────
    'profile.appbar_title':   'Complete your profile',
    'profile.heading':        'Creating your account',
    'profile.desc':           'Please fill in the details below to create your medical record.',
    'profile.first_name':     'First name',
    'profile.first_hint':     'Ex: Mary',
    'profile.last_name':      'Last name',
    'profile.last_hint':      'Ex: Johnson',
    'profile.phone':          'Phone Number',
    'profile.phone_hint':     'Ex: 0722 000 000',
    'profile.continue_btn':   'CONTINUE',
    'profile.continue_sem':   'Save profile and continue',
    'profile.save_error':     'Save error. Please try again.',

    // ── Emergency ─────────────────────────────────────────────────────────
    'emergency.title':        'Medical Emergency Detected!',
    'emergency.subtitle':     'Calling 112 in 10 seconds...',
    'emergency.call_btn':     'CALL NOW',
    'emergency.cancel_btn':   'No, cancel',
    'emergency.call_sem':     'Call 112 now',
    'emergency.cancel_sem':   'Cancel the emergency call',

    // ── Confirmation ──────────────────────────────────────────────────────
    'confirm.title':          'Consultation saved successfully.',
    'confirm.subtitle':       'Data was securely recorded in the local file.',
    'confirm.ai_label':       'AI Assistant Response',

    // ── Waiting room ──────────────────────────────────────────────────────
    'waiting.connecting':     "Connecting to Dr. Bogheanu's office...",
    'waiting.consent_title':  'Consultation Agreement',
    'waiting.consent_text':   'By using this service, you agree to share your medical data with Dr. Bogheanu for remote consultation.',
    'waiting.consent_1':      'Secure access to your medical history.',
    'waiting.consent_2':      'Session recording for clinical accuracy.',
    'waiting.consent_3':      'Privacy guaranteed by medical protocol.',
    'waiting.info':           'Please read before starting.',
    'waiting.agree_btn':      'I agree',
    'waiting.cancel_btn':     'CANCEL',
    'waiting.note':           'The consultation will start immediately after you press the confirm button.',
    'waiting.agree_sem':      'I agree to the consultation',
    'waiting.cancel_sem':     'Cancel the call',
    'waiting.conn_error':     'Connection error:',
    'waiting.clinic':         'Medical Office',

    // ── Video consultation ────────────────────────────────────────────────
    'video.header':           'CONSULT DR. BOGHEANU',
    'video.connecting':       'Connecting...',
    'video.you_label':        'YOU',
    'video.muted':            'Muted',
    'video.unmuted':          'Sound',
    'video.end_call':         'End',
    'video.chat_hint':        'Message or document...',
    'video.chat_soon':        'Chat and documents — coming soon',
    'video.mute_sem':         'Disable microphone',
    'video.unmute_sem':       'Enable microphone',
    'video.end_sem':          'End consultation',
    'video.chat_sem':         'Open chat and documents',

    // ── Dashboard ─────────────────────────────────────────────────────────
    'dashboard.greeting_small':   'Good day,',
    'dashboard.health_title':     'Your health status',
    'dashboard.no_condition':     'No condition recorded',
    'dashboard.last_dialog':      'Last dialog:',
    'dashboard.no_dialog':        'No previous dialog',
    'dashboard.doctor_label':     'Your doctor:',
    'dashboard.doctor_name':      'Dr. Adriana Bogheanu',
    'dashboard.next_appt':        'Next appointment',
    'dashboard.no_appt':          'No appointment',
    'dashboard.active_treatment': 'Active treatment',
    'dashboard.no_treatment':     'No treatment',
    'dashboard.recent_activity':  'Recent activity',
    'dashboard.triage_dialog':    'AI Triage Dialog',
    'dashboard.no_activity':      'No recent activity',
    'dashboard.priority_normal':  'Normal priority',
    'dashboard.priority_urgent':  'Urgent',
    'dashboard.cta_btn':          '+ Register a new issue',

    // ── Shared / nav ──────────────────────────────────────────────────────
    'nav.home':               'Home',
    'nav.history':            'Medical Record',
    'nav.doctor':             'Doctor',
    'lang.switch_sem':        'Change Language / Schimbă Limba',
  };

  /// Returns the string for [key] in [lang].
  /// Falls back to Romanian if [lang] is unknown or [key] is missing.
  /// Falls back to [key] itself if absent from both maps.
  static String of(String lang, String key) {
    if (lang == 'en') return _en[key] ?? _ro[key] ?? key;
    return _ro[key] ?? key;
  }

  /// Convenience: build a greeting with the patient first name.
  static String greeting(String lang, String? firstName) {
    final prefix = lang == 'en' ? 'Good day' : 'Bună ziua';
    return (firstName != null && firstName.isNotEmpty)
        ? '$prefix, $firstName!'
        : '$prefix!';
  }

  /// Build OTP wrong-code message with remaining attempts substituted.
  static String otpWrongCode(String lang, int remaining) {
    if (lang == 'en') {
      return 'Wrong code. Please try again. ($remaining attempt${remaining == 1 ? '' : 's'} remaining)';
    }
    return 'Cod incorect. Vă rugăm încercați din nou. ($remaining încercări rămase)';
  }

  /// Build download error message with optional reason.
  static String downloadFail(String lang, String? reason) {
    if (reason == null) return of(lang, 'download.fail_msg');
    if (lang == 'en') {
      return 'Download failed ($reason). Please check your WiFi and try again.';
    }
    return 'Descărcarea a eșuat ($reason). Verificați conexiunea WiFi și încercați din nou.';
  }

  /// Build progress percentage label.
  static String downloadProgress(String lang, int pct) {
    return '$pct% ${of(lang, 'download.progress_pct')}';
  }
}
