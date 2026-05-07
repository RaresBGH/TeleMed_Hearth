// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors
// Design reference: stitch_telemed_k/chat_screen/screen.png + code.html

import 'dart:async';
import 'dart:io';

import '../../core/l10n/app_strings.dart';
import '../../core/providers/language_provider.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/chat_message.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/medplum_auth_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/services/ai_engine_service.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/ocr_service.dart';
import '../widgets/image_preview_screen.dart';

// ── Design tokens (matches Stitch palette from code.html) ─────────────────────

const Color _brandBlue    = Color(0xFF5BA4CF);
const Color _onSurface    = Color(0xFF191C1F);
const Color _muted        = Color(0xFF70787F);
const Color _outlineVar   = Color(0xFFBFC7CF);
const Color _aiBubbleBg   = Color(0x1A5BA4CF); // brand-blue/10
const Color _surfContainer = Color(0xFFECEEF2);

// ── Screen ────────────────────────────────────────────────────────────────────

class MedicalResponseScreen extends ConsumerStatefulWidget {
  final String initialResponse;
  final bool isEmergency;
  /// When resuming a saved dialog from Dosar Medical, the prior messages are
  /// passed here and used to pre-populate the chat instead of the default
  /// "Aveți și alte simptome?" seed message.
  final List<ChatMessage>? initialMessages;
  /// When set, adds a patient message with this text and immediately triggers
  /// AI inference — used by the "Trimite mesaj" doctor flow.
  final String? initialPrompt;

  const MedicalResponseScreen({
    super.key,
    required this.initialResponse,
    required this.isEmergency,
    this.initialMessages,
    this.initialPrompt,
  });

  @override
  ConsumerState<MedicalResponseScreen> createState() =>
      _MedicalResponseScreenState();
}

class _MedicalResponseScreenState
    extends ConsumerState<MedicalResponseScreen> {

  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isRecording      = false;
  bool _isProcessing     = false;
  bool _isFinalizing     = false;
  bool _isPhotoAnalyzing = false;
  // Screen-level duplicate guard: set true in _onFinalize() before writing.
  bool _screenFinalized  = false;
  // Guard: doctor Communications loaded once per screen open.
  bool _doctorMessagesLoaded = false;

  // ── Streaming shim (Dart-side typewriter) ─────────────────────────────────
  /// Accumulates streaming text while an inference response is being typed out.
  String _streamingText = '';

  // ── Opening state ──────────────────────────────────────────────────────────
  /// True after the first AI response has been received — gates the triage card.
  bool _hasFirstAiResponse = false;

  // ── Audio playback (voice messages) ──────────────────────────────────────
  late final AudioPlayer _audioPlayer;
  StreamSubscription<PlayerState>? _playerSubscription;
  String? _playingMessagePath; // attachmentPath of the currently playing message

  // Readable from any method; build() uses ref.watch for reactivity.
  String get _lang => ref.read(languageProvider);
  // Set to true when finalize is requested while _isProcessing is true.
  // Checked by inference handlers to abort appending a response mid-finalize.
  bool _cancelRequested  = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    // Reset session isolation so this screen gets a fresh FHIR history injection.
    ref.read(aiEngineServiceProvider).resetSession();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      // Doctor "Trimite mesaj" flow — add patient message and immediately
      // trigger AI inference so the doctor receives a response on open.
      _messages.add(ChatMessage(
        role: 'patient',
        text: widget.initialPrompt!,
        timestamp: DateTime.now(),
      ));
      _isProcessing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final result = await ref
              .read(aiEngineServiceProvider)
              .evaluateText(widget.initialPrompt!);
          if (!mounted || _cancelRequested) {
            if (mounted) setState(() { _isProcessing = false; _cancelRequested = false; });
            return;
          }
          _appendAiResponse(result);
        } catch (_) {
          if (mounted) setState(() => _isProcessing = false);
        }
      });
    } else if (widget.initialMessages != null && widget.initialMessages!.isNotEmpty) {
      // Resume from Dosar Medical or doctor preseed — restore prior conversation.
      _messages.addAll(widget.initialMessages!);
      _hasFirstAiResponse = true; // resuming — triage card shown immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(medicalSessionProvider.notifier).clearPreseed();
      });
    } else {
      // Fresh triage entry: if there is a patient message + AI response from the
      // home-screen triage, seed both bubbles immediately so the chat is populated.
      final session = ref.read(medicalSessionProvider);
      if (widget.initialResponse.isNotEmpty &&
          session.lastPatientMessage != null) {
        _messages.add(ChatMessage(
          role: 'patient',
          text: session.lastPatientMessage!,
          timestamp: DateTime.now(),
        ));
        _messages.add(ChatMessage(
          role: 'ai',
          text: widget.initialResponse,
          timestamp: DateTime.now(),
        ));
        _hasFirstAiResponse = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(medicalSessionProvider.notifier).clearPatientMessage();
          }
        });
      } else {
        // No prior exchange — show welcome card and default AI prompt.
        _messages.add(ChatMessage(
          role: 'ai',
          text: AppStrings.of(_lang, 'chat.followup_prompt'),
          timestamp: DateTime.now(),
        ));
      }
    }
    _textController.addListener(() => setState(() {}));
    // Load doctor Communications after the initial message list is set.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDoctorCommunications();
    });
  }

  Future<void> _loadDoctorCommunications() async {
    if (_doctorMessagesLoaded) return;
    _doctorMessagesLoaded = true;
    try {
      final cnp  = ref.read(loginCnpProvider);
      final comms = await ref.read(fhirRepositoryProvider).getCommunications(cnp: cnp);
      if (!mounted) return;
      final doctorComms = comms.where((c) {
        final exts = (c['extension'] as List?) ?? [];
        return exts.any((e) =>
            e['url'] == 'isPatient' && e['valueBoolean'] == false);
      }).toList();
      if (doctorComms.isEmpty) return;
      final doctorMessages = doctorComms.map((c) {
        final payload = (c['payload'] as List?)?.first as Map?;
        final text = payload?['contentString'] as String? ?? '';
        final sentStr = c['sent'] as String? ?? '';
        final ts = sentStr.isNotEmpty
            ? DateTime.tryParse(sentStr) ?? DateTime.now()
            : DateTime.now();
        return ChatMessage(role: 'doctor', text: text, timestamp: ts);
      }).toList();
      setState(() {
        _messages.addAll(doctorMessages);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
    } catch (e) {
      debugPrint('MedicalResponseScreen._loadDoctorCommunications error: $e');
    }
  }

  @override
  void dispose() {
    // Release microphone if the screen is destroyed while recording or processing.
    unawaited(ref.read(audioRecordingServiceProvider).stopAndRelease());
    _textController.dispose();
    _scrollController.dispose();
    _playerSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Document attachment ───────────────────────────────────────────────────────

  Future<void> _onAttachDocument() async {
    final lang = _lang;
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'wav', 'mp3', 'aac', 'm4a'],
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(lang, 'attachment.error_analyse'),
            style: const TextStyle(fontSize: 16)),
      ));
      return;
    }
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    final AttachmentType attachType;
    if (ext == 'pdf') {
      attachType = AttachmentType.pdf;
    } else if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
      attachType = AttachmentType.image;
    } else {
      attachType = AttachmentType.audio;
    }
    final fileName = file.name;

    setState(() {
      _messages.add(ChatMessage(
        role: 'patient',
        text: fileName,
        timestamp: DateTime.now(),
        attachmentPath: path,
        attachmentType: attachType,
      ));
      if (attachType != AttachmentType.audio) _isProcessing = true;
    });
    _scrollToBottom();

    if (attachType == AttachmentType.audio) return; // audio: no AI inference

    try {
      final Map<String, dynamic> aiResult;
      if (attachType == AttachmentType.image) {
        aiResult = await ref.read(aiEngineServiceProvider).evaluateMedia(File(path));
      } else {
        // PDF: attempt OCR, fall back to filename-only message
        final ocrText = await OcrService.extractText(path);
        if (ocrText.isNotEmpty) {
          aiResult = await ref.read(aiEngineServiceProvider).evaluateText(ocrText);
        } else {
          final fallback = AppStrings.of(lang, 'attachment.fallback_msg')
              .replaceAll('{filename}', fileName);
          aiResult = await ref.read(aiEngineServiceProvider).evaluateText(fallback);
        }
      }
      if (!mounted || _cancelRequested) {
        if (mounted) setState(() { _isProcessing = false; _cancelRequested = false; });
        return;
      }
      _appendAiResponse(aiResult);

      // Save DocumentReference to Medplum (best-effort, no UI impact on failure).
      final cnp = ref.read(loginCnpProvider);
      final mimeType =
          attachType == AttachmentType.pdf ? 'application/pdf' : 'image/jpeg';
      unawaited(
        ref.read(medplumRepositoryProvider).saveDocumentReference(
          patientCnp: cnp,
          filePath: path,
          mimeType: mimeType,
          description: fileName,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() { _isProcessing = false; _cancelRequested = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(lang, 'attachment.error_analyse'),
            style: const TextStyle(fontSize: 16)),
      ));
    }
  }

  // ── Audio playback ────────────────────────────────────────────────────────────

  Future<void> _togglePlayback(ChatMessage msg) async {
    final path = msg.attachmentPath;
    if (path == null) return;

    if (_playingMessagePath == path) {
      await _audioPlayer.stop();
      setState(() => _playingMessagePath = null);
      return;
    }

    _playerSubscription?.cancel();
    if (_playingMessagePath != null) await _audioPlayer.stop();

    try {
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();
      setState(() => _playingMessagePath = path);

      _playerSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingMessagePath = null);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _playingMessagePath = null);
    }
  }

  // ── Image full-screen preview ─────────────────────────────────────────────────

  void _showImagePreview(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImagePreviewScreen(
          imagePath: imagePath,
          title: AppStrings.of(_lang, 'attachment.image_label'),
        ),
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  Future<void> _onBack() async {
    final bool? choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(AppStrings.of(_lang, 'chat.back_title')),
        content: Text(
          AppStrings.of(_lang, 'chat.back_content'),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              AppStrings.of(_lang, 'chat.back_exit'),
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppStrings.of(_lang, 'chat.finalize_btn'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == true) {
      await _onFinalize();
    } else if (choice == false) {
      if (Navigator.canPop(context)) {
        // Pushed via Navigator (e.g. specialist flow) — pop back to caller.
        Navigator.pop(context);
      } else {
        // Flat-nav entry — reset session to return to dashboard.
        await ref.read(medicalSessionProvider.notifier).reset();
      }
    }
    // choice == null means the dialog was dismissed; stay in chat.
  }

  // ── Scroll ──────────────────────────────────────────────────────────────────

  /// Builds a formatted string of the conversation so far, to be passed as
  /// [customPrompt] so the AI model maintains context across turns.
  /// Messages with non-null [attachmentType] are skipped (they carry UI
  /// placeholder text, not patient information).
  String _buildConversationHistory() {
    final buffer = StringBuffer('\nCONVERSATION SO FAR:\n');
    for (final msg in _messages) {
      if (msg.attachmentType != null) continue; // skip media placeholders
      final text = msg.text.trim();
      if (text.isEmpty) continue;
      final speaker = msg.role == 'ai' ? 'Assistant' : 'Patient';
      buffer.writeln('$speaker: $text');
    }
    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── AI response append ──────────────────────────────────────────────────────

  void _appendAiResponse(Map<String, dynamic> result) {
    final String text =
        (result['response'] as String?)?.trim().isNotEmpty == true
            ? result['response'] as String
            : AppStrings.of(_lang, 'chat.no_understand');
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _isPhotoAnalyzing = false;
      _streamingText = '';
      _hasFirstAiResponse = true; // reveal triage card after first AI reply
      _messages.add(ChatMessage(role: 'ai', text: text, timestamp: DateTime.now()));
    });
    _scrollToBottom();
  }

  /// Streams [result]'s response word-by-word (typewriter shim), then appends
  /// the full [ChatMessage] and updates metadata.
  /// TODO: replace with native EventChannel streaming when available.
  Future<void> _streamAndAppendAiResponse(Map<String, dynamic> result) async {
    final String text =
        (result['response'] as String?)?.trim().isNotEmpty == true
            ? result['response'] as String
            : AppStrings.of(_lang, 'chat.no_understand');
    if (!mounted) return;

    // Stream the words progressively.
    await for (final chunk in AiEngineService.streamWords(text)) {
      if (!mounted || _cancelRequested) break;
      setState(() => _streamingText = chunk);
      _scrollToBottom();
    }
    if (!mounted) return;

    // Commit the full message and clear streaming text.
    setState(() {
      _isProcessing     = false;
      _isPhotoAnalyzing = false;
      _streamingText    = '';
      _hasFirstAiResponse = true;
      _messages.add(ChatMessage(role: 'ai', text: text, timestamp: DateTime.now()));
    });
    _scrollToBottom();
  }

  // ── Mic ─────────────────────────────────────────────────────────────────────

  Future<void> _onMicTap() async {
    final audioService = ref.read(audioRecordingServiceProvider);

    if (_isRecording) {
      final wavPath = await audioService.stopRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        // Show patient's own bubble immediately while AI processes.
        _messages.add(ChatMessage(
            role: 'patient',
            text: AppStrings.of(_lang, 'chat.voice_bubble'),
            timestamp: DateTime.now(),
            attachmentPath: wavPath.isNotEmpty ? wavPath : null,
            attachmentType: wavPath.isNotEmpty ? AttachmentType.audio : null));
      });
      _scrollToBottom();

      if (wavPath.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      try {
        final result =
            await ref.read(aiEngineServiceProvider).evaluateAudio(
                File(wavPath), customPrompt: _buildConversationHistory());
        audioService.deleteWavFile(wavPath);
        if (_cancelRequested) {
          if (mounted) setState(() { _isProcessing = false; _cancelRequested = false; });
          return;
        }
        _appendAiResponse(result);
      } catch (_) {
        audioService.deleteWavFile(wavPath);
        if (mounted) setState(() { _isProcessing = false; _cancelRequested = false; });
      }
    } else {
      final hasPermission = await audioService.requestPermission();
      if (!mounted) return;
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.of(_lang, 'chat.mic_no_perm'),
              style: const TextStyle(fontSize: 16)),
        ));
        return;
      }
      try {
        await audioService.startRecording();
        if (mounted) setState(() => _isRecording = true);
      } catch (_) {}
    }
  }

  // ── Camera ──────────────────────────────────────────────────────────────────

  Future<void> _onCameraTap() async {
    final cameraService = ref.read(cameraServiceProvider);
    final hasPermission = await cameraService.requestPermission();
    if (!mounted) return;

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(_lang, 'chat.cam_no_perm'),
            style: const TextStyle(fontSize: 16)),
      ));
      return;
    }

    final imagePath = await cameraService.captureImage();
    if (!mounted || imagePath == null) return;

    setState(() {
      _isProcessing = true;
      _isPhotoAnalyzing = true;
      // Show patient's own bubble immediately while AI processes.
      _messages.add(ChatMessage(
          role: 'patient',
          text: AppStrings.of(_lang, 'chat.photo_bubble'),
          timestamp: DateTime.now(),
          attachmentPath: imagePath,
          attachmentType: AttachmentType.image));
    });
    _scrollToBottom();

    try {
      final result =
          await ref.read(aiEngineServiceProvider).evaluateMedia(
              File(imagePath), customPrompt: _buildConversationHistory());
      cameraService.deleteTempFile(imagePath);
      if (_cancelRequested) {
        if (mounted) setState(() { _isProcessing = false; _isPhotoAnalyzing = false; _cancelRequested = false; });
        return;
      }
      _appendAiResponse(result);
    } catch (_) {
      cameraService.deleteTempFile(imagePath);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isPhotoAnalyzing = false;
          _cancelRequested = false;
        });
      }
    }
  }

  // ── Text send ────────────────────────────────────────────────────────────────

  Future<void> _onSendTap() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() {
      _messages.add(ChatMessage(
          role: 'patient', text: text, timestamp: DateTime.now()));
      _textController.clear();
      _isProcessing = true;
    });
    _scrollToBottom();

    try {
      final result =
          await ref.read(aiEngineServiceProvider).evaluateText(
              text, customPrompt: _buildConversationHistory());
      if (_cancelRequested) {
        if (mounted) setState(() { _isProcessing = false; _cancelRequested = false; });
        return;
      }
      // Use streaming shim for typewriter effect on text responses.
      await _streamAndAppendAiResponse(result);
    } catch (_) {
      if (mounted) setState(() { _isProcessing = false; _cancelRequested = false; });
    }
  }

  // ── Emergency chip ───────────────────────────────────────────────────────────

  Future<void> _onEmergencyTap() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Finalize dialog ───────────────────────────────────────────────────────────

  Future<void> _onFinalize() async {
    if (_isFinalizing || _screenFinalized) return;
    _screenFinalized = true; // set before any await to prevent race conditions

    // If an inference call is in progress, signal it to abort and wait up to
    // 3 seconds. After the timeout we force-finalize with whatever messages
    // are already in _messages — never leave the app in a stuck state.
    if (_isProcessing) {
      setState(() => _cancelRequested = true);
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (mounted && _isProcessing && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
      setState(() => _cancelRequested = false);
    }

    // Explicitly clear cancel flag before the FHIR write — guards the edge case
    // where _isProcessing was already false when finalize was triggered, leaving
    // _cancelRequested true from a previous inference cancellation.
    setState(() {
      _cancelRequested = false;
      _isFinalizing    = true;
    });

    // Release the microphone before writing FHIR data.
    await ref.read(audioRecordingServiceProvider).stopAndRelease();
    if (!mounted) return;

    try {
      await ref
          .read(medicalSessionProvider.notifier)
          .finalizeConsultation(List.unmodifiable(_messages));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(_lang, 'chat.saved_snack'),
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;

      // Explicit patient finalization — reset session and return to dashboard.
      await ref.read(medicalSessionProvider.notifier).reset();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.of(_lang, 'chat.save_error')} $e',
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider); // register watcher so _lang getter rebuilds on change
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  // Show welcome card until the first AI response arrives.
                  if (!_hasFirstAiResponse && !_isProcessing)
                    _buildWelcomeCard()
                  else if (_hasFirstAiResponse)
                    _buildTriageCard(),
                  const SizedBox(height: 24),
                  if (_hasFirstAiResponse) _buildSectionDivider(),
                  const SizedBox(height: 16),
                  ..._messages.map(_buildBubble),
                  // Streaming typewriter bubble (shows while words are emitting).
                  if (_isProcessing && _streamingText.isNotEmpty)
                    _buildStreamingBubble(_streamingText),
                  if (_isProcessing && _streamingText.isEmpty)
                    _buildTypingIndicator(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      leading: Semantics(
        button: true,
        label: AppStrings.of(_lang, 'profil.back_sem'),
        child: InkWell(
          onTap: _onBack,
          child: const SizedBox(
            width: 64,
            height: 64,
            child: Icon(Icons.arrow_back, color: _brandBlue, size: 24),
          ),
        ),
      ),
      titleSpacing: 0,
      title: Builder(builder: (_) {
        final doctorName = ref.read(medicalSessionProvider).lastDoctorName;
        final title = (doctorName != null && doctorName.isNotEmpty)
            ? doctorName
            : AppStrings.of(_lang, 'chat.appbar_title');
        return Text(
          title,
          style: const TextStyle(
            color: _brandBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        );
      }),
    );
  }

  // ── Welcome card (shown before first AI response) ─────────────────────────────

  Widget _buildWelcomeCard() {
    final doctorName = ref.read(medicalSessionProvider).lastDoctorName;
    final isDoctorContext = doctorName != null && doctorName.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x145BA4CF), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDoctorContext ? Icons.chat_bubble_outline : Icons.health_and_safety,
            color: _brandBlue, size: 48),
          const SizedBox(height: 16),
          Text(
            isDoctorContext ? doctorName : AppStrings.of(_lang, 'assistant.title'),
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: _onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isDoctorContext
                ? AppStrings.of(_lang, 'chat.doctor_message_subtitle')
                : AppStrings.of(_lang, 'assistant.subtitle'),
            style: const TextStyle(fontSize: 16, color: _muted, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Streaming bubble (typewriter shim) ────────────────────────────────────────

  Widget _buildStreamingBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _aiBubbleBg,
              borderRadius: BorderRadius.only(
                topLeft:     Radius.circular(20),
                topRight:    Radius.circular(20),
                bottomLeft:  Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500,
                  color: _onSurface, height: 1.45),
            ),
          ),
        ),
      ),
    );
  }

  // ── Triage card ───────────────────────────────────────────────────────────────

  Widget _buildTriageCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x145BA4CF),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row: robot icon + "Analiza simptomelor"
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1A5BA4CF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: _brandBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppStrings.of(_lang, 'chat.section_label'),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Initial AI response text
          Text(
            widget.initialResponse.isNotEmpty
                ? widget.initialResponse
                : AppStrings.of(_lang, 'chat.default_response'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Priority chip
          _buildPriorityChip(),
        ],
      ),
    );
  }

  Widget _buildPriorityChip() {
    if (widget.isEmergency) {
      return GestureDetector(
        onTap: _onEmergencyTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDED),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emergency, color: Color(0xFFBA1A1A), size: 16),
              const SizedBox(width: 6),
              Text(
                AppStrings.of(_lang, 'chat.emergency_chip'),
                style: TextStyle(
                  color: Color(0xFFBA1A1A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16),
          const SizedBox(width: 6),
          Text(
            AppStrings.of(_lang, 'chat.priority_normal'),
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section divider ───────────────────────────────────────────────────────────

  Widget _buildSectionDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE0E2E7))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AppStrings.of(_lang, 'chat.divider_label'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE0E2E7))),
      ],
    );
  }

  // ── Chat bubbles ──────────────────────────────────────────────────────────────

  Widget _buildBubble(ChatMessage msg) {
    // Doctor bubble — distinct left-aligned warm grey card with doctor label.
    if (msg.role == 'doctor') {
      final doctorName = ref.read(medicalSessionProvider).lastDoctorName ?? 'Doctor';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    'Dr. $doctorName',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF40A060),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7EE),
                    borderRadius: const BorderRadius.only(
                      topLeft:     Radius.circular(4),
                      topRight:    Radius.circular(20),
                      bottomLeft:  Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                        color: _onSurface, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isAi = msg.role == 'ai';
    final Widget content = _buildBubbleContent(msg, isAi);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: msg.attachmentType == AttachmentType.image ? 8 : 16,
              vertical:   msg.attachmentType == AttachmentType.image ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: isAi ? _aiBubbleBg : _brandBlue,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(20),
                topRight:    const Radius.circular(20),
                bottomLeft:  Radius.circular(isAi ? 4 : 20),
                bottomRight: Radius.circular(isAi ? 20 : 4),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleContent(ChatMessage msg, bool isAi) {
    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: isAi ? _onSurface : Colors.white,
      height: 1.45,
    );

    switch (msg.attachmentType) {
      case AttachmentType.audio:
        final path = msg.attachmentPath;
        final isPlaying = path != null && _playingMessagePath == path;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                size: 32,
                color: isAi ? _brandBlue : Colors.white,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _togglePlayback(msg),
            ),
            const SizedBox(width: 8),
            Text(AppStrings.of(_lang, 'voice.message_label'), style: textStyle),
          ],
        );

      case AttachmentType.image:
        final path = msg.attachmentPath;
        if (path == null) return Text(msg.text, style: textStyle);
        return GestureDetector(
          onTap: () => _showImagePreview(path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              width: 200,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 48, color: Colors.grey),
            ),
          ),
        );

      case AttachmentType.pdf:
      case AttachmentType.document:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Color(0xFFAB1118), size: 32),
            const SizedBox(width: 8),
            Flexible(child: Text(msg.text, style: textStyle)),
          ],
        );

      case null:
        return Text(msg.text, style: textStyle);
    }
  }

  // ── Typing indicator ──────────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: _aiBubbleBg,
            borderRadius: BorderRadius.only(
              topLeft:     Radius.circular(20),
              topRight:    Radius.circular(20),
              bottomLeft:  Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: _isPhotoAnalyzing
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_camera, size: 16, color: _brandBlue),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.of(_lang, 'chat.analyzing_photo'),
                      style: const TextStyle(
                        fontSize: 15,
                        color: _muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              : const _TypingDots(),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final bool canSend =
        _textController.text.trim().isNotEmpty && !_isProcessing;
    final bool hasAiResponse = _messages.any((m) => m.role == 'ai');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Finalizează Dialogul" — shown as soon as at least one AI response exists.
          if (hasAiResponse) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isFinalizing || _isProcessing) ? null : _onFinalize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
                  disabledBackgroundColor: _outlineVar,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isFinalizing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        AppStrings.of(_lang, 'chat.finalize_btn'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Icon row + text field
          Row(
        children: [
          // Attachment — opens file picker (pdf/image/audio)
          _InputIconButton(
            icon: Icons.attach_file,
            onTap: _isProcessing ? null : _onAttachDocument,
          ),
          const SizedBox(width: 6),
          // Mic — turns red while recording
          _InputIconButton(
            icon: _isRecording ? Icons.stop : Icons.mic,
            iconColor: _isRecording ? Colors.red : _brandBlue,
            bgColor: _isRecording
                ? Colors.red.withValues(alpha: 0.12)
                : _aiBubbleBg,
            onTap: _isProcessing ? null : _onMicTap,
          ),
          const SizedBox(width: 6),
          // Camera
          _InputIconButton(
            icon: Icons.photo_camera,
            onTap: _isProcessing ? null : _onCameraTap,
          ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: _surfContainer,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _outlineVar),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _textController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16, color: _onSurface),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: AppStrings.of(_lang, 'chat.hint'),
                  hintStyle: TextStyle(color: _muted, fontSize: 16),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onSubmitted: canSend ? (_) => _onSendTap() : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button — active only when text is present
          GestureDetector(
            onTap: canSend ? _onSendTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: canSend ? _brandBlue : _outlineVar,
                shape: BoxShape.circle,
                boxShadow: canSend
                    ? const [
                        BoxShadow(
                          color: Color(0x405BA4CF),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ), // end Row
        ], // end Column.children
      ), // end Column
    );
  }
}

// ── Input icon button ─────────────────────────────────────────────────────────

class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color bgColor;

  const _InputIconButton({
    required this.icon,
    this.onTap,
    this.iconColor = _brandBlue,
    this.bgColor = _aiBubbleBg,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: onTap != null ? bgColor : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap != null ? iconColor : Colors.grey,
          size: 26,
        ),
      ),
    );
  }
}

// ── Typing dots animation ─────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _anims = List.generate(3, (i) {
      final double start = i * 0.2;
      return Tween<double>(begin: 0, end: 6).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, start + 0.4, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8 + _anims[i].value,
            decoration: BoxDecoration(
              color: _brandBlue.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
