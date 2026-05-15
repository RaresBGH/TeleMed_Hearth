// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors
// Design reference: stitch_telemed_k/chat_screen/screen.png + code.html

import 'dart:async';
import 'dart:io';

import '../../core/l10n/app_strings.dart';
import '../../core/providers/language_provider.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
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
  /// The AI's actual first triage response text (from lastAiResponse).
  /// Separate from initialResponse so the triage card and AI bubble can show
  /// the AI's assessment rather than the patient placeholder ('[Voice message]').
  final String? initialAiResponse;
  /// WAV file path of the patient's home-screen voice recording, used to seed
  /// the audio player on the first voice bubble.
  final String? initialAudioPath;
  /// JPEG file path of the patient's home-screen photo capture, used to seed
  /// the image thumbnail on the first photo bubble.
  final String? initialImagePath;
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
    this.initialAiResponse,
    this.initialAudioPath,
    this.initialImagePath,
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
  // Info card dismissed for this session.
  bool _infoDismissed = false;
  // True when the AI signals the conversation is complete (ready_to_finalize).
  bool _readyToFinalize = false;
  // Category from the last AI inference result — stored for FHIR Observation.
  String? _lastAiCategory;

  // ── Streaming shim (Dart-side typewriter) ─────────────────────────────────
  /// Accumulates streaming text while an inference response is being typed out.
  String _streamingText = '';

  // ── Audio playback (voice messages) ──────────────────────────────────────
  late final AudioPlayer _audioPlayer;
  StreamSubscription<PlayerState>? _playerSubscription;
  String? _playingMessagePath; // attachmentPath of the currently playing message

  // ref.read() is safe in all contexts including async callbacks.
  // Language reactivity in the build path is handled by
  // ref.watch(languageProvider) at the top of build(), whose result is
  // passed as a `lang` parameter to every synchronous build-path method.
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
    // Sync AI engine language with the UI language set at login.
    unawaited(ref.read(aiEngineServiceProvider).setLanguage(ref.read(languageProvider)));
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(medicalSessionProvider.notifier).clearPreseed();
      });
    } else {
      // Fresh triage entry: if there is a patient message + AI response from the
      // home-screen triage, seed both bubbles immediately so the chat is populated.
      final session = ref.read(medicalSessionProvider);
      if (widget.initialResponse.isNotEmpty &&
          session.lastPatientMessage != null) {
        // Verify the initial image path is still accessible before seeding the bubble.
        // Camera temp files can be cleaned up between home screen and chat screen.
        final imgPath = widget.initialImagePath;
        final validImagePath = (imgPath != null && File(imgPath).existsSync())
            ? imgPath
            : null;
        _messages.add(ChatMessage(
          role: 'patient',
          text: session.lastPatientMessage!,
          timestamp: DateTime.now(),
          attachmentType: session.lastPatientMessage == '[Voice message]'
              ? AttachmentType.audio
              : session.lastPatientMessage == '[Photo]'
                  ? AttachmentType.image
                  : null,
          attachmentPath: session.lastPatientMessage == '[Voice message]'
              ? widget.initialAudioPath
              : session.lastPatientMessage == '[Photo]'
                  ? validImagePath
                  : null,
        ));
        _messages.add(ChatMessage(
          role: 'ai',
          text: widget.initialAiResponse ?? widget.initialResponse,
          timestamp: DateTime.now(),
        ));
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
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    // Capture the service reference before super.dispose() invalidates ref.
    // The unawaited Future completes on the captured service object, not on ref
    // or the widget tree, preventing the deactivated ancestor assertion.
    final audioService = ref.read(audioRecordingServiceProvider);
    audioService.stopAndRelease().catchError((_) {});
    _textController.removeListener(_onTextChanged);
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
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(lang, 'attachment.error_analyse'),
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    final AttachmentType attachType;
    if (ext == 'pdf' || ext == 'doc' || ext == 'docx') {
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
        aiResult = await ref.read(aiEngineServiceProvider).evaluateMedia(File(path),
            customPrompt: _buildConversationHistory(10));
      } else {
        // PDF/doc: attempt OCR with 10s timeout, fall back to acknowledgment prompt.
        String ocrText = '';
        try {
          ocrText = await OcrService.extractText(path)
              .timeout(const Duration(seconds: 10), onTimeout: () => '');
        } catch (_) {
          ocrText = '';
        }
        if (ocrText.isNotEmpty) {
          aiResult = await ref.read(aiEngineServiceProvider).evaluateText(ocrText,
              customPrompt: _buildConversationHistory(10));
        } else {
          final fallback = AppStrings.of(lang, 'chat.pdf_attached')
              .replaceAll('{filename}', fileName);
          aiResult = await ref.read(aiEngineServiceProvider).evaluateText(fallback,
              customPrompt: _buildConversationHistory(10));
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
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  // ── Audio playback ────────────────────────────────────────────────────────────

  Future<void> _togglePlayback(ChatMessage msg) async {
    final path = msg.attachmentPath;
    if (path == null) return;

    if (_playingMessagePath == path) {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() => _playingMessagePath = null);
      return;
    }

    _playerSubscription?.cancel();
    if (_playingMessagePath != null) await _audioPlayer.stop();
    if (!mounted) return;

    if (!File(path).existsSync()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(_lang, 'error.audio_unavailable')),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    try {
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();
      if (!mounted) return;
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
    if (!mounted) return;
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
  String _buildConversationHistory(int maxMessages) {
    final recentMessages = _messages.length > maxMessages
        ? _messages.sublist(_messages.length - maxMessages)
        : List<ChatMessage>.from(_messages);

    // Per-modality cap: keep at most 2 patient voice turns and 2 patient photo
    // turns in the context window. Older voice/photo patient turns are rewritten
    // to a consolidated placeholder so the AI sees the structural sequence but
    // not the raw text of every redundant attachment turn. AI responses to all
    // turns (including rewritten ones) remain verbatim.
    final placeholder = '[${AppStrings.of(_lang, 'chat.information_accounted_label')}]';

    int voicePatientCount = 0;
    int photoPatientCount = 0;
    for (final msg in recentMessages.reversed) {
      if (msg.role != 'patient') continue;
      if (msg.attachmentType == AttachmentType.audio) voicePatientCount++;
      if (msg.attachmentType == AttachmentType.image) photoPatientCount++;
    }

    // Build a mutable copy with placeholders rewritten for over-cap turns.
    // Iterate oldest→newest so that we rewrite the oldest turns first.
    int voiceSeen = 0;
    int photoSeen = 0;
    final contextMessages = recentMessages.reversed.toList().reversed.map((msg) {
      if (msg.role != 'patient') return msg;
      if (msg.attachmentType == AttachmentType.audio) {
        voiceSeen++;
        // Keep only the most-recent 2: rewrite if this is an older one.
        final keepFromEnd = voicePatientCount - 2;
        if (voiceSeen <= keepFromEnd) {
          return ChatMessage(
            role: msg.role,
            text: placeholder,
            timestamp: msg.timestamp,
            attachmentType: msg.attachmentType,
            attachmentPath: msg.attachmentPath,
          );
        }
      }
      if (msg.attachmentType == AttachmentType.image) {
        photoSeen++;
        final keepFromEnd = photoPatientCount - 2;
        if (photoSeen <= keepFromEnd) {
          return ChatMessage(
            role: msg.role,
            text: placeholder,
            timestamp: msg.timestamp,
            attachmentType: msg.attachmentType,
            attachmentPath: msg.attachmentPath,
          );
        }
      }
      return msg;
    }).toList();

    final aiCount = contextMessages.where((m) => m.role == 'ai').length;
    final remaining = 5 - aiCount;
    final header = remaining > 0
        ? '\nCONVERSATION SO FAR (AI responses: $aiCount/5 — ask up to $remaining more questions):\n'
        : '\nCONVERSATION SO FAR (AI responses: $aiCount/5 — PROVIDE SUMMARY AND FINALIZE):\n';
    final buffer = StringBuffer(header);
    for (final msg in contextMessages) {
      // Skip document/pdf filename placeholders; include audio "[Voice message]"
      // and image "[Photo]" so the AI has patient-turn context on those rounds.
      if (msg.attachmentType == AttachmentType.pdf ||
          msg.attachmentType == AttachmentType.document) continue;
      if (msg.role == 'doctor') continue;
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
    if (!mounted) return;
    final String text =
        (result['response'] as String?)?.trim().isNotEmpty == true
            ? result['response'] as String
            : AppStrings.of(_lang, 'chat.no_understand');
    final bool readyToFinalize = result['ready_to_finalize'] == true;
    final String? category = result['category'] as String?;
    setState(() {
      _isProcessing = false;
      _isPhotoAnalyzing = false;
      _streamingText = '';
      _messages.add(ChatMessage(role: 'ai', text: text, timestamp: DateTime.now()));
      if (readyToFinalize) _readyToFinalize = true;
      if (category != null) _lastAiCategory = category;
    });
    _scrollToBottom();
  }

  /// Streams [result]'s response word-by-word (typewriter shim), then appends
  /// the full [ChatMessage] and updates metadata.
  /// TODO: replace with native EventChannel streaming when available.
  Future<void> _streamAndAppendAiResponse(Map<String, dynamic> result) async {
    if (!mounted) return;
    final String text =
        (result['response'] as String?)?.trim().isNotEmpty == true
            ? result['response'] as String
            : AppStrings.of(_lang, 'chat.no_understand');
    final bool readyToFinalize = result['ready_to_finalize'] == true;
    final String? category = result['category'] as String?;

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
      _messages.add(ChatMessage(role: 'ai', text: text, timestamp: DateTime.now()));
      if (readyToFinalize) _readyToFinalize = true;
      if (category != null) _lastAiCategory = category;
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
            text: '[Voice message]',
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
                File(wavPath),
                customPrompt: _buildConversationHistory(4));
        audioService.deleteWavFile(wavPath);
        // Update voice bubble with AAC path if background transcoding finished
        // during inference. Falls back to old WAV path gracefully via existsSync check.
        final aacPath = audioService.lastAacPath;
        if (aacPath != null && File(aacPath).existsSync()) {
          final idx = _messages.indexWhere((m) => m.attachmentPath == wavPath);
          if (idx != -1 && mounted) {
            final msg = _messages[idx];
            setState(() {
              _messages[idx] = ChatMessage(
                role: msg.role,
                text: msg.text,
                timestamp: msg.timestamp,
                attachmentType: msg.attachmentType,
                attachmentPath: aacPath,
                senderName: msg.senderName,
              );
            });
          }
        }
        if (_cancelRequested) {
          if (mounted) setState(() { _isProcessing = false; _cancelRequested = false; });
          return;
        }
        if (!mounted) return;
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
          backgroundColor: Colors.red.shade700,
        ));
        return;
      }
      try {
        await audioService.startRecording();
        if (mounted) setState(() => _isRecording = true);
      } catch (e) {
        debugPrint('Mic start error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(_lang, 'error.mic_unavailable')),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
    }
  }

  // ── Camera helpers ───────────────────────────────────────────────────────────

  /// Copies [tempPath] to the app documents directory so the image bubble
  /// survives after the camera temp file is deleted.
  /// Updates the ChatMessage in [_messages] whose attachmentPath == [tempPath].
  /// Returns the permanent path on success, null on failure.
  Future<String?> _copyImageToPermanentPath(String tempPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final permanentPath =
          '${appDir.path}/telemed_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(tempPath).copy(permanentPath);
      final idx = _messages.indexWhere((m) => m.attachmentPath == tempPath);
      if (idx != -1 && mounted) {
        final msg = _messages[idx];
        setState(() {
          _messages[idx] = ChatMessage(
            role: msg.role,
            text: msg.text,
            timestamp: msg.timestamp,
            attachmentType: msg.attachmentType,
            attachmentPath: permanentPath,
            senderName: msg.senderName,
          );
        });
      }
      return permanentPath;
    } catch (e) {
      debugPrint('_copyImageToPermanentPath error: $e');
      return null;
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
        backgroundColor: Colors.red.shade700,
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
          text: '[Photo]',
          timestamp: DateTime.now(),
          attachmentPath: imagePath,
          attachmentType: AttachmentType.image));
    });
    _scrollToBottom();

    try {
      final result =
          await ref.read(aiEngineServiceProvider).evaluateMedia(File(imagePath));
      await _copyImageToPermanentPath(imagePath);
      cameraService.deleteTempFile(imagePath);
      if (_cancelRequested) {
        if (mounted) setState(() { _isProcessing = false; _isPhotoAnalyzing = false; _cancelRequested = false; });
        return;
      }
      if (!mounted) return;
      _appendAiResponse(result);
    } catch (e) {
      debugPrint('Camera evaluation error: $e');
      await _copyImageToPermanentPath(imagePath);
      cameraService.deleteTempFile(imagePath);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isPhotoAnalyzing = false;
          _cancelRequested = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(_lang, 'error.camera_unavailable')),
            backgroundColor: Colors.red.shade700,
          ));
      }
    }
  }

  // ── Text send ────────────────────────────────────────────────────────────────

  Future<void> _onSendTap() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(
          role: 'patient', text: text, timestamp: DateTime.now()));
      _isProcessing = true;
    });
    _scrollToBottom();

    try {
      final result =
          await ref.read(aiEngineServiceProvider).evaluateText(
              text, customPrompt: _buildConversationHistory(10));
      if (_cancelRequested) {
        if (mounted) setState(() { _isProcessing = false; _cancelRequested = false; });
        return;
      }
      if (!mounted) return;
      // Use streaming shim for typewriter effect on text responses.
      await _streamAndAppendAiResponse(result);
    } catch (e) {
      debugPrint('Text inference error: $e');
      if (mounted) {
        setState(() { _isProcessing = false; _cancelRequested = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(_lang, 'error.inference_failed')),
            backgroundColor: Colors.red.shade700,
          ));
      }
    }
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
      // Generate a one-sentence clinical summary before writing to FHIR.
      // Conversation history is embedded in the text itself (no customPrompt)
      // to avoid the large-context issue that causes the engine to return fallback.
      String? clinicalSummary;
      try {
        final history = _buildConversationHistory(10);
        final summaryRequest = _lang == 'ro'
            ? 'Pe baza conversației de mai sus, generează un rezumat clinic scurt de o propoziție.'
            : 'Based on the conversation above, generate a brief one-sentence clinical summary.';
        final combinedPrompt = history.isNotEmpty
            ? '$history\n\n$summaryRequest'
            : summaryRequest;
        // 30-second timeout; TimeoutException re-thrown so outer catch shows error.
        final summaryResult = await ref.read(aiEngineServiceProvider).evaluateText(
          combinedPrompt,
        ).timeout(const Duration(seconds: 30));
        final raw = summaryResult['response'] as String?;
        final isFallback = raw == null || raw.isEmpty ||
            raw.contains('not available') || raw.contains('nu este disponibil');
        clinicalSummary = isFallback ? null : raw;
        // Part C: log finalize inference outcome to on-device JSONL.
        final ts = DateTime.now().toUtc().toIso8601String();
        unawaited(ref.read(aiEngineServiceProvider).appendDebugLog(
          '{"ts":"$ts","method":"finalize","inputLen":${combinedPrompt.length},'
          '"sysPromptLen":0,"samplingApplied":{"temperature":0.3,"topP":0.9,"topK":40},'
          '"rawOutputLen":${raw?.length ?? 0},"elapsedMs":0,'
          '"error":${isFallback ? '"fallback"' : 'null'}}',
        ));
      } on TimeoutException {
        // Propagate to outer catch for user-visible error + retry path.
        rethrow;
      } catch (_) {
        clinicalSummary = null;
      }

      await ref
          .read(medicalSessionProvider.notifier)
          .finalizeConsultation(
            List.unmodifiable(_messages),
            lastAiText: clinicalSummary?.isNotEmpty == true ? clinicalSummary : null,
            aiCategory: _lastAiCategory,
          );

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
      // _isFinalizing stays true until widget is disposed by navigation;
      // it is only reset to false in the catch block below on error.
      await ref.read(medicalSessionProvider.notifier).reset();
    } catch (e) {
      if (!mounted) return;
      // Reset both flags so the user can retry (Fix #5 left _screenFinalized
      // permanently true on error, making retry impossible).
      setState(() {
        _isFinalizing    = false;
        _screenFinalized = false;
      });
      final msg = (e is TimeoutException)
          ? AppStrings.of(_lang, 'chat.finalize_timeout')
          : '${AppStrings.of(_lang, 'chat.save_error')} $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(lang),
        body: Column(
          children: [
            if (!_infoDismissed) _buildInfoCard(lang),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  ..._messages.map((m) => _buildBubble(m, lang)),
                  // Streaming typewriter bubble (shows while words are emitting).
                  if (_isProcessing && _streamingText.isNotEmpty)
                    _buildStreamingBubble(_streamingText),
                  if (_isProcessing && _streamingText.isEmpty)
                    _buildTypingIndicator(lang),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _buildInputBar(lang),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF6FF),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: _brandBlue, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              AppStrings.of(lang, 'chat.info_card_text'),
              style: const TextStyle(
                fontSize: 12,
                color: _onSurface,
                height: 1.45,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _infoDismissed = true),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 16, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(String lang) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      leading: Semantics(
        button: true,
        label: AppStrings.of(lang, 'profil.back_sem'),
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
            : AppStrings.of(lang, 'chat.appbar_title');
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

  // ── Chat bubbles ──────────────────────────────────────────────────────────────

  Widget _buildBubble(ChatMessage msg, String lang) {
    final bool isAi = msg.role == 'ai';
    final Widget content = _buildBubbleContent(msg, isAi, lang);
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

  Widget _buildBubbleContent(ChatMessage msg, bool isAi, String lang) {
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
            Text(AppStrings.of(lang, 'voice.message_label'), style: textStyle),
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
        return GestureDetector(
          onTap: () async {
            final path = msg.attachmentPath;
            if (path == null) return;
            final uri = Uri.file(path);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(AppStrings.of(_lang, 'error.pdf_open_failed')),
                backgroundColor: Colors.red.shade700,
              ));
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.picture_as_pdf, color: Color(0xFFAB1118), size: 32),
                  const SizedBox(width: 8),
                  Flexible(child: Text(msg.text, style: textStyle)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.of(_lang, 'attachment.tap_to_open'),
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
        );

      case null:
        return Text(msg.text, style: textStyle);
    }
  }

  // ── Typing indicator ──────────────────────────────────────────────────────────

  Widget _buildTypingIndicator(String lang) {
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
                      AppStrings.of(lang, 'chat.analyzing_photo'),
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

  Widget _buildInputBar(String lang) {
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
                onPressed: (_isFinalizing || _isProcessing || _screenFinalized) ? null : _onFinalize,
                style: ElevatedButton.styleFrom(
                  // Always blue when active; greyed only when processing/finalizing.
                  // _readyToFinalize adds a glow via elevation to signal the AI
                  // is done — but button is never disabled solely because of it.
                  backgroundColor: _brandBlue,
                  disabledBackgroundColor: _outlineVar,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: _readyToFinalize ? 6 : 0,
                  shadowColor: _readyToFinalize
                      ? _brandBlue.withOpacity(0.55)
                      : Colors.transparent,
                ),
                child: _isFinalizing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        AppStrings.of(lang, 'chat.finalize_btn'),
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
                ? Colors.red.withOpacity(0.12)
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
                  hintText: AppStrings.of(lang, 'chat.hint'),
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
              color: _brandBlue.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
