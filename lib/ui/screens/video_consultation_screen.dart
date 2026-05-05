// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/chat_message.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medplum_auth_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../widgets/image_preview_screen.dart';

/// A message exchanged during an in-call chat session.
class _CallMessage {
  final String id;
  final String text;
  final bool isPatient;
  final DateTime timestamp;
  final String? attachmentPath;
  final AttachmentType? attachmentType;

  const _CallMessage({
    required this.id,
    required this.text,
    required this.isPatient,
    required this.timestamp,
    this.attachmentPath,
    this.attachmentType,
  });
}

// Override at build time: --dart-define=SIGNALING_URL=wss://...
// Default keeps working without dart-define for hackathon builds.
const _kSignalingUrl = String.fromEnvironment(
  'SIGNALING_URL',
  defaultValue: 'wss://telemed-signal.duckdns.org',
);

class VideoConsultationScreen extends ConsumerStatefulWidget {
  final String? appointmentId;

  const VideoConsultationScreen({super.key, this.appointmentId});

  @override
  ConsumerState<VideoConsultationScreen> createState() =>
      _VideoConsultationScreenState();
}

class _VideoConsultationScreenState
    extends ConsumerState<VideoConsultationScreen>
    with SingleTickerProviderStateMixin {

  // ── WebRTC objects ─────────────────────────────────────────────────────────
  final _localRenderer  = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  MediaStream?       _localStream;
  RTCPeerConnection? _peerConnection;

  // ── Signaling ──────────────────────────────────────────────────────────────
  WebSocket? _signalingSocket;
  // Patient is always the initiator — creates the offer when joining the room.
  // Doctor answers via a future web/admin client.
  final bool _isInitiator = true;

  // ── Screen state ───────────────────────────────────────────────────────────
  bool     _isMuted      = false;
  bool     _isConnecting = true;
  bool     _peerLeft     = false;

  // ── In-call chat ───────────────────────────────────────────────────────────
  final List<_CallMessage>    _callMessages  = [];
  final TextEditingController _chatController = TextEditingController();
  bool _chatOpen = false;
  late final DraggableScrollableController _sheetController;

  // ── In-call audio playback ─────────────────────────────────────────────────
  late final AudioPlayer _callAudioPlayer;
  StreamSubscription<PlayerState>? _callPlayerSub;
  String? _callPlayingPath;

  String get _lang => ref.read(languageProvider);
  Duration _callDuration = Duration.zero;

  // ── Animation (voice visualizer bars) ─────────────────────────────────────
  Timer?               _durationTimer;
  late AnimationController      _animController;
  late List<Animation<double>>  _barAnimations;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _callAudioPlayer = AudioPlayer();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() {
      // Close chat when sheet is dragged below visible threshold.
      if (_sheetController.isAttached &&
          _sheetController.size < 0.05 &&
          _chatOpen &&
          mounted) {
        setState(() => _chatOpen = false);
      }
    });
    _initAnimController();
    _initWebRTC();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _animController.dispose();
    _chatController.dispose();
    _callPlayerSub?.cancel();
    _callAudioPlayer.dispose();
    _sheetController.dispose();
    // Restore normal AI mode when call ends.
    try { ref.read(aiEngineServiceProvider).setDoctorPresent(false); } catch (_) {}
    // Signal leave before closing WebSocket.
    try {
      _signalingSocket?.add(jsonEncode({
        'type': 'leave',
        'room': widget.appointmentId ?? 'default',
      }));
      _signalingSocket?.close();
    } catch (_) {}
    if (_localStream    != null) unawaited(_localStream!.dispose());
    if (_peerConnection != null) unawaited(_peerConnection!.close());
    unawaited(_localRenderer.dispose());
    unawaited(_remoteRenderer.dispose());
    super.dispose();
  }

  // ── Animation setup ────────────────────────────────────────────────────────

  void _initAnimController() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Symmetrical bar heights: [40, 60, 80, 60, 40] dp.
    // Each bar oscillates between 50 % and 100 % of its target height,
    // with staggered Interval curves to avoid lockstep movement.
    const baseHeights = [40.0, 60.0, 80.0, 60.0, 40.0];
    const intervals   = [
      Interval(0.0, 0.6, curve: Curves.easeInOut),
      Interval(0.1, 0.7, curve: Curves.easeInOut),
      Interval(0.2, 0.8, curve: Curves.easeInOut),
      Interval(0.1, 0.7, curve: Curves.easeInOut),
      Interval(0.0, 0.6, curve: Curves.easeInOut),
    ];
    _barAnimations = List.generate(
      5,
      (i) => Tween<double>(
        begin: baseHeights[i] * 0.5,
        end:   baseHeights[i],
      ).animate(CurvedAnimation(
        parent: _animController,
        curve:  intervals[i],
      )),
    );
  }

  // ── WebRTC ─────────────────────────────────────────────────────────────────

  Future<void> _initWebRTC() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final config = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {
            'urls':       'turn:34.185.191.34:3478',
            'username':   'telemed',
            'credential': 'TeleMed_TURN_2026!',
          },
        ],
        'iceTransportPolicy': 'all',
      };
      _peerConnection = await createPeerConnection(config);

      final constraints = <String, dynamic>{
        'audio': true,
        'video': {'facingMode': 'user'},
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      if (mounted) {
        setState(() {
          _localRenderer.srcObject = _localStream;
          _isConnecting = false;
        });
      }

      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // Fires when the remote peer adds a stream — shows remote video.
      _peerConnection!.onAddStream = (stream) {
        if (mounted) setState(() => _remoteRenderer.srcObject = stream);
      };

      // Forward ICE candidates to the signaling server for the remote peer.
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        _signalingSocket?.add(jsonEncode({
          'type':         'candidate',
          'room':         widget.appointmentId ?? 'default',
          'candidate':    candidate.candidate,
          'sdpMid':       candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }));
      };

      // Start call duration counter.
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _callDuration += const Duration(seconds: 1));
        }
      });

      // Connect to signaling server and (if initiator) create offer.
      await _initSignaling();
      // Doctor is present — switch AI to silent documentation mode.
      ref.read(aiEngineServiceProvider).setDoctorPresent(true);
      debugPrint('WebRTC initialized — signaling connected, doctor-present mode active');
    } catch (e) {
      debugPrint('VideoConsultationScreen._initWebRTC error: $e');
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  // ── WebRTC Signaling ───────────────────────────────────────────────────────

  Future<void> _initSignaling() async {
    try {
      _signalingSocket = await WebSocket.connect(_kSignalingUrl);
      // Join the room keyed by appointmentId.
      _signalingSocket!.add(jsonEncode({
        'type': 'join',
        'room': widget.appointmentId ?? 'default',
      }));

      _signalingSocket!.listen(
        _onSignalingMessage,
        onError: (e) => debugPrint('Signaling error: $e'),
        onDone:  () => debugPrint('Signaling connection closed'),
      );

      // Patient is always the initiator — create offer immediately after joining.
      if (_isInitiator) await _createOffer();
    } catch (e) {
      debugPrint('Could not connect to signaling server: $e — call continues with local video only');
      // Fail silently: call UI remains functional, remote video stays black.
    }
  }

  Future<void> _onSignalingMessage(dynamic raw) async {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final type = msg['type'] as String?;

    switch (type) {
      case 'offer':
        await _peerConnection?.setRemoteDescription(
            RTCSessionDescription(msg['sdp'] as String?, 'offer'));
        await _createAnswer();
        break;
      case 'answer':
        await _peerConnection?.setRemoteDescription(
            RTCSessionDescription(msg['sdp'] as String?, 'answer'));
        break;
      case 'candidate':
        await _peerConnection?.addCandidate(RTCIceCandidate(
          msg['candidate'] as String?,
          msg['sdpMid']    as String?,
          msg['sdpMLineIndex'] as int?,
        ));
        break;
      case 'peer_joined':
        // A new peer entered the room (doctor joined after patient).
        // Re-send the offer so the doctor receives it and can answer.
        await _createOffer();
        break;
      case 'leave':
        // The other peer left the room — show the overlay so the patient
        // knows the call has ended and can tap the end-call button.
        if (mounted) setState(() => _peerLeft = true);
        break;
    }
  }

  Future<void> _createOffer() async {
    try {
      final offer = await _peerConnection!.createOffer({});
      await _peerConnection!.setLocalDescription(offer);
      _signalingSocket?.add(jsonEncode({
        'type': 'offer',
        'room': widget.appointmentId ?? 'default',
        'sdp':  offer.sdp,
      }));
      debugPrint('Offer sent to room: ${widget.appointmentId ?? "default"}');
    } catch (e) {
      debugPrint('Create offer error: $e');
    }
  }

  Future<void> _createAnswer() async {
    try {
      final answer = await _peerConnection!.createAnswer({});
      await _peerConnection!.setLocalDescription(answer);
      _signalingSocket?.add(jsonEncode({
        'type': 'answer',
        'room': widget.appointmentId ?? 'default',
        'sdp':  answer.sdp,
      }));
      debugPrint('Answer sent to room: ${widget.appointmentId ?? "default"}');
    } catch (e) {
      debugPrint('Create answer error: $e');
    }
  }

  void _toggleMute() {
    final newMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !newMuted; // enabled = true when NOT muted
    });
    setState(() => _isMuted = newMuted);
  }

  Future<void> _endCall() async {
    // Generate Gemma 4 summary if chat messages were exchanged.
    if (_callMessages.isNotEmpty) await _saveCallSummary();
    if (!mounted) return;

    final lang = _lang;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.myDoctor);
    }
    if (_callMessages.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(lang, 'call.summary_saved'),
            style: const TextStyle(fontSize: 16)),
      ));
    }
  }

  // ── Chat — send text ─────────────────────────────────────────────────────────

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    final msg = _CallMessage(
      id: DateTime.now().toIso8601String(),
      text: text,
      isPatient: true,
      timestamp: DateTime.now(),
    );
    setState(() => _callMessages.add(msg));
    _chatController.clear();
    _persistMessage(msg);
  }

  // ── Chat — attach file ────────────────────────────────────────────────────────

  Future<void> _attachCallFile() async {
    // Ensure the chat panel is visible before the picker appears.
    if (!_chatOpen) {
      setState(() => _chatOpen = true);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;

    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
    } catch (_) {
      return; // picker dismissed or plugin error — silent fail in call context
    }
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    final AttachmentType attachType =
        ext == 'pdf' ? AttachmentType.pdf : AttachmentType.image;

    final msg = _CallMessage(
      id: DateTime.now().toIso8601String(),
      text: file.name,
      isPatient: true,
      timestamp: DateTime.now(),
      attachmentPath: path,
      attachmentType: attachType,
    );
    setState(() => _callMessages.add(msg));
    _persistMessage(msg);
  }

  // ── Chat — persist as FHIR Communication ─────────────────────────────────────

  void _persistMessage(_CallMessage msg) {
    final cnp = ref.read(loginCnpProvider);
    final String? mimeType = msg.attachmentType == AttachmentType.pdf
        ? 'application/pdf'
        : msg.attachmentType == AttachmentType.image
            ? 'image/jpeg'
            : null;
    // Fire-and-forget: Communication sync failure must not interrupt the call.
    ref.read(medplumRepositoryProvider).saveCommunication(
      patientCnp: cnp,
      appointmentId: widget.appointmentId,
      text: msg.text,
      isPatient: msg.isPatient,
      timestamp: msg.timestamp,
      attachmentPath: msg.attachmentPath,
      mimeType: mimeType,
      attachmentTitle: msg.attachmentType != null ? msg.text : null,
    ).then((_) {}).catchError((e) {
      debugPrint('VideoConsultationScreen: Communication persist error: $e');
    });
  }

  // ── Call end — Gemma 4 summary ───────────────────────────────────────────────

  Future<void> _saveCallSummary() async {
    try {
      final transcript = _callMessages.map((m) {
        final h   = m.timestamp.hour.toString().padLeft(2, '0');
        final min = m.timestamp.minute.toString().padLeft(2, '0');
        return '${m.isPatient ? "Pacient" : "Doctor"} [$h:$min]: ${m.text}';
      }).join('\n');

      const prompt =
          'Rezumă această conversație medicală în 3-5 propoziții clare. '
          'Evidențiază simptomele menționate, recomandările medicului '
          'și orice acțiuni urmărite. Conversație:\n';

      String summaryText;
      try {
        final result = await ref
            .read(aiEngineServiceProvider)
            .evaluateText('$prompt$transcript');
        summaryText = ((result['response'] as String?)?.trim().isNotEmpty == true)
            ? result['response'] as String
            : transcript;
      } catch (_) {
        summaryText = transcript;
      }

      final cnp = ref.read(loginCnpProvider);
      await ref.read(fhirRepositoryProvider).saveObservation({
        'resourceType': 'Observation',
        'status': 'final',
        'category': [{'coding': [{'code': 'consultation-summary'}]}],
        'code': {'text': 'Rezumat consultație video'},
        'subject': {
          'identifier': {
            'system': 'urn:oid:1.2.40.0.10.1.4.3.1',
            'value': cnp,
          },
        },
        'valueString': summaryText,
        'effectiveDateTime': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('VideoConsultationScreen._saveCallSummary error: $e');
    }
  }

  // ── In-call audio playback ────────────────────────────────────────────────────

  Future<void> _toggleCallPlayback(_CallMessage msg) async {
    final path = msg.attachmentPath;
    if (path == null) return;
    if (_callPlayingPath == path) {
      await _callAudioPlayer.stop();
      setState(() => _callPlayingPath = null);
      return;
    }
    _callPlayerSub?.cancel();
    if (_callPlayingPath != null) await _callAudioPlayer.stop();
    try {
      await _callAudioPlayer.setFilePath(path);
      await _callAudioPlayer.play();
      setState(() => _callPlayingPath = path);
      _callPlayerSub = _callAudioPlayer.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _callPlayingPath = null);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _callPlayingPath = null);
    }
  }

  // ── Image full-screen (in-call) ───────────────────────────────────────────────

  void _showCallImagePreview(String imagePath) {
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

  // ── Chat panel (DraggableScrollableSheet in Stack) ───────────────────────────

  Widget _buildChatPanel() {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.45,
        minChildSize: 0.0,   // Allow full collapse via drag or tap-outside
        maxChildSize: 0.85,
        snap: true,
        snapSizes: const [0.45, 0.85],
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                child: Row(
                  children: [
                    Text(
                      AppStrings.of(_lang, 'call.chat_hint').split('.').first,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _chatOpen = false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Message list
              Expanded(
                child: _callMessages.isEmpty
                    ? Center(
                        child: Text(
                          AppStrings.of(_lang, 'call.chat_hint'),
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _callMessages.length,
                        itemBuilder: (_, i) => _buildCallMessageBubble(_callMessages[i]),
                      ),
              ),
              // Input row (48dp buttons — constrained video overlay space)
              Container(
                padding: EdgeInsets.fromLTRB(
                    12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E2E2))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file,
                          color: Color(0xFF5BA4CF), size: 26),
                      onPressed: _attachCallFile,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 48, minHeight: 48),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF1a1c1c)),
                        decoration: InputDecoration(
                          hintText: AppStrings.of(_lang, 'call.chat_hint'),
                          hintStyle: const TextStyle(
                              color: Color(0xFF40484e)),
                          filled: true,
                          fillColor: Colors.white,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendChatMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send,
                          color: Color(0xFF5BA4CF), size: 26),
                      onPressed: _sendChatMessage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 48, minHeight: 48),
                    ),
                  ],
                ),
              ),
            ],
            ), // Column
          ), // SafeArea
        ),
      ),
    );
  }

  Widget _buildCallMessageBubble(_CallMessage msg) {
    const patientBg = Color(0xFF5BA4CF);
    const doctorBg  = Color(0xFFF3F3F3);
    final bg        = msg.isPatient ? patientBg : doctorBg;
    final textColor = msg.isPatient ? Colors.white : const Color(0xFF1A1C1C);
    final timeStr   = DateFormatter.formatTimeOfDay(
        msg.timestamp.hour, msg.timestamp.minute);

    Widget content;
    switch (msg.attachmentType) {
      case AttachmentType.audio:
        final isPlaying = _callPlayingPath == msg.attachmentPath;
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPlaying
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                size: 32,
                color: msg.isPatient ? Colors.white : const Color(0xFF5BA4CF),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _toggleCallPlayback(msg),
            ),
            const SizedBox(width: 6),
            Text(AppStrings.of(_lang, 'voice.message_label'),
                style: TextStyle(fontSize: 15, color: textColor)),
          ],
        );
        break;

      case AttachmentType.image:
        final path = msg.attachmentPath;
        content = path != null
            ? GestureDetector(
                onTap: () => _showCallImagePreview(path),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    width: 120, height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                  ),
                ),
              )
            : Text(msg.text, style: TextStyle(fontSize: 15, color: textColor));
        break;

      case AttachmentType.pdf:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Color(0xFFAB1118), size: 28),
            const SizedBox(width: 6),
            Flexible(child: Text(msg.text,
                style: TextStyle(fontSize: 15, color: textColor))),
          ],
        );
        break;

      case null:
        content = Text(msg.text,
            style: TextStyle(fontSize: 15, color: textColor));
    }

    return Align(
      alignment: msg.isPatient ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: msg.isPatient
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: content,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
            child: Text(
              timeStr,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) => DateFormatter.formatDuration(d);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider); // register watcher so _lang getter rebuilds on change
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 — Remote video (fills screen) or connecting placeholder
          _buildRemoteVideo(),

          // Layer 2 — Subtle top gradient for header legibility
          _buildTopGradient(),

          // Layer 3 — PiP: patient's own camera (top-right)
          _buildPiP(),

          // Layer 4 — Voice visualizer (above bottom panel, hidden when muted)
          if (!_isMuted) _buildVisualizer(),

          // Layer 5 — Bottom control panel (glassmorphism)
          _buildBottomPanel(context),

          // Layer 5.5 — Peer-left overlay (shown when remote peer disconnects)
          if (_peerLeft)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call_end, size: 48, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.of(_lang, 'call.peer_left'),
                      style: const TextStyle(
                          fontSize: 18, color: Colors.white,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () { _endCall(); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5BA4CF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(200, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(AppStrings.of(_lang, 'call.end'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // Layer 6 — Top header (over video, SafeArea-wrapped)
          _buildTopHeader(),

          // Layer 7 — Slide-up chat panel (toggled by chat strip tap)
          if (_chatOpen) ...[
            // Transparent overlay: tapping outside the sheet collapses it.
            // Constrained to exclude the bottom 240dp (control panel + safe area)
            // so the end-call and mute buttons remain tappable.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 240,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _sheetController.animateTo(
                  0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            _buildChatPanel(),
          ],
        ],
      ),
    );
  }

  // ── Layer 1: Remote video ──────────────────────────────────────────────────

  Widget _buildRemoteVideo() {
    if (_isConnecting) {
      return Container(
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF5BA4CF)),
            const SizedBox(height: 24),
            Text(
              AppStrings.of(_lang, 'video.connecting'),
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ],
        ),
      );
    }
    return RTCVideoView(
      _remoteRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  // ── Layer 2: Top gradient ──────────────────────────────────────────────────

  Widget _buildTopGradient() {
    return Positioned(
      top: 0, left: 0, right: 0,
      height: 80,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Color(0x66000000), Colors.transparent],
          ),
        ),
      ),
    );
  }

  // ── Layer 3: PiP ──────────────────────────────────────────────────────────

  Widget _buildPiP() {
    return Positioned(
      top: 80, right: 16,
      child: SizedBox(
        width: 120, height: 160,
        child: Stack(
          children: [
            // Video fill
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
            // Border overlay (2dp white/30 %)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
            // "TU" label
            Positioned(
              bottom: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppStrings.of(_lang, 'video.you_label'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Layer 4: Voice visualizer ──────────────────────────────────────────────

  Widget _buildVisualizer() {
    const opacities = [0.4, 0.6, 1.0, 0.6, 0.4];
    return Positioned(
      bottom: 220, left: 0, right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (i) => Container(
              width:  6,
              height: _barAnimations[i].value,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF5BA4CF)
                    .withValues(alpha: opacities[i]),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
        ),
      ),
    );
  }

  // ── Layer 5: Bottom control panel ─────────────────────────────────────────

  Widget _buildBottomPanel(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(
                  color:       Color(0x0F1a1c1c),
                  blurRadius:  32,
                  spreadRadius: -4,
                  offset:      Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Button row
                Row(
                  children: [
                    Expanded(child: _buildMuteButton()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildEndCallButton()),
                  ],
                ),
                const SizedBox(height: 16),
                // Chat strip
                _buildChatStrip(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMuteButton() {
    return Semantics(
      button: true,
      label: _isMuted
          ? AppStrings.of(_lang, 'call.mute_enable')
          : AppStrings.of(_lang, 'call.mute_disable'),
      child: GestureDetector(
        onTap: _toggleMute,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                size:  32,
                color: const Color(0xFF5BA4CF),
              ),
              const SizedBox(height: 8),
              Text(
                _isMuted ? AppStrings.of(_lang, 'video.muted') : AppStrings.of(_lang, 'video.unmuted'),
                style: const TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      Color(0xFF1a1c1c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndCallButton() {
    return Semantics(
      button: true,
      label: AppStrings.of(_lang, 'call.end'),
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _endCall();
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color:        const Color(0xFFab1118),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1a1c1c), width: 2),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.call_end, size: 32, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                AppStrings.of(_lang, 'video.end_call'),
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color:      Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatStrip(BuildContext context) {
    return Semantics(
      label: AppStrings.of(_lang, 'call.open_chat'),
      child: GestureDetector(
        onTap: () => setState(() => _chatOpen = !_chatOpen),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E2E2)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _attachCallFile,
                icon: const Icon(
                  Icons.attach_file,
                  size:  32,
                  color: Color(0xFF5BA4CF),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _chatOpen = !_chatOpen),
                  child: Text(
                    AppStrings.of(_lang, 'call.chat_hint'),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                onPressed: _sendChatMessage,
                icon: const Icon(
                  Icons.send,
                  size:  32,
                  color: Color(0xFF5BA4CF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layer 6: Top header ────────────────────────────────────────────────────

  Widget _buildTopHeader() {
    final shadow = Shadow(
      color:      Colors.black.withValues(alpha: 0.6),
      blurRadius: 8,
      offset:     const Offset(0, 1),
    );
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.of(_lang, 'video.header'),
                  style: TextStyle(
                    fontSize:    18,
                    fontWeight:  FontWeight.bold,
                    color:       Colors.white,
                    letterSpacing: 1.5,
                    shadows:     [shadow],
                  ),
                ),
              ),
              Text(
                _formatDuration(_callDuration),
                style: TextStyle(
                  fontSize: 16,
                  color:    Colors.white,
                  shadows:  [shadow],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
