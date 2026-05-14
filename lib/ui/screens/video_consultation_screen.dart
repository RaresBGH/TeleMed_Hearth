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
// just_audio removed — in-call audio playback removed with chat (FIX 4)


import '../../core/l10n/app_strings.dart';
import '../../core/models/chat_message.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medplum_auth_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/fhir_extension_utils.dart';
// image_preview_screen removed — in-call image preview removed with chat (FIX 4)

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
  // Always true — initiator role is fixed (patient always creates offer).
  // Post-hackathon: make dynamic for multi-party or doctor-initiated calls.
  final bool _isInitiator = true;

  // ── Screen state ───────────────────────────────────────────────────────────
  bool     _isMuted      = false;
  bool     _isConnecting = true;
  bool     _peerLeft     = false;

  // ── In-call activity panel ────────────────────────────────────────────────────
  bool _chatOpen = false;  // controls panel visibility (kept for panel toggle)
  late final DraggableScrollableController _sheetController;
  List<Map<String, dynamic>> _activityObservations = [];
  bool _activityLoaded = false;

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
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() {
      if (!mounted || !_chatOpen) return;
      try {
        if (_sheetController.size < 0.05) {
          setState(() => _chatOpen = false);
        }
      } catch (_) {
        // Controller detached during animation — close panel defensively.
        if (mounted && _chatOpen) {
          setState(() => _chatOpen = false);
        }
      }
    });
    _initAnimController();
    _initWebRTC();
    _loadActivityData();
  }

  Future<void> _loadActivityData() async {
    try {
      final cnp = ref.read(loginCnpProvider);
      final all = await ref.read(fhirRepositoryProvider).getPatientHistory(cnp: cnp);
      if (!mounted) return;
      final obs = all
          .where((o) =>
              (o['resourceType'] as String?) == 'Observation' &&
              o['effectiveDateTime'] != null)
          .toList()
        ..sort((a, b) {
          final aD = DateTime.tryParse(a['effectiveDateTime'] as String? ?? '') ??
              DateTime(0);
          final bD = DateTime.tryParse(b['effectiveDateTime'] as String? ?? '') ??
              DateTime(0);
          return bD.compareTo(aD);
        });
      setState(() {
        _activityObservations = obs.length > 5 ? obs.sublist(0, 5) : obs;
        _activityLoaded = true;
      });
    } catch (e) {
      debugPrint('VideoConsultationScreen._loadActivityData error: $e');
      if (mounted) setState(() => _activityLoaded = true);
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _animController.dispose();
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
    _localStream?.getTracks().forEach((track) => track.stop());
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

      const String _turnCredential =
          String.fromEnvironment('TURN_CREDENTIAL', defaultValue: '');
      // Add TURN_USERNAME to GitHub Actions secrets.
      const String _turnUsername =
          String.fromEnvironment('TURN_USERNAME', defaultValue: '');
      final config = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {
            // TODO: Move to dart-define for infrastructure portability — post-hackathon.
            'urls':       'turn:34.185.191.34:3478',
            'username':   _turnUsername,
            'credential': _turnCredential,
          },
        ],
        'iceTransportPolicy': 'all',
      };
      _peerConnection = await createPeerConnection(config);

      final constraints = <String, dynamic>{
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width':     {'ideal': 640, 'max': 640},
          'height':    {'ideal': 480, 'max': 480},
          'frameRate': {'ideal': 24,  'max': 30},
        },
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

      // Cap outgoing video bitrate to prevent flooding the connection.
      final senders = await _peerConnection!.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          final params = sender.parameters; // synchronous getter
          final encodings = params.encodings ?? [];
          if (encodings.isEmpty) {
            encodings.add(RTCRtpEncoding(
              maxBitrate: 500000,
              maxFramerate: 24,
            ));
          } else {
            // Mutate in-place to preserve ssrc and other immutable fields.
            encodings[0].maxBitrate = 500000;
            encodings[0].maxFramerate = 24;
          }
          params.encodings = encodings;
          await sender.setParameters(params);
        }
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
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(_lang, 'call.webrtc_error'))),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(_lang, 'call.signaling_error'))),
        );
      }
    }
  }

  Future<void> _onSignalingMessage(dynamic raw) async {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Signaling: malformed frame ignored: $e');
      return;
    }
    final type = msg['type'] as String?;

    switch (type) {
      case 'offer':
        try {
          await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(msg['sdp'] as String?, 'offer'));
        } catch (e) {
          debugPrint('SDP error: $e');
          return;
        }
        await _createAnswer();
        break;
      case 'answer':
        try {
          await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(msg['sdp'] as String?, 'answer'));
        } catch (e) {
          debugPrint('SDP error: $e');
          return;
        }
        break;
      case 'candidate':
        try {
          await _peerConnection?.addCandidate(RTCIceCandidate(
            msg['candidate'] as String?,
            msg['sdpMid']    as String?,
            msg['sdpMLineIndex'] as int?,
          ));
        } catch (e) {
          debugPrint('ICE candidate error: $e');
          return;
        }
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
      // 'chat' case removed — in-call chat replaced by Activity panel (FIX 4).
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
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(_lang, 'call.webrtc_error'))));
      }
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
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(_lang, 'call.webrtc_error'))));
      }
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
    if (!mounted) return;
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.myDoctor);
    }
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
    // Persist to Medplum only — WebSocket chat send removed (FIX 4).
    _persistMessage(msg);
  }

  // ── Chat — persist as FHIR Communication ─────────────────────────────────────

  void _persistMessage(_CallMessage msg) {
    // Communication is saved to Medplum but the Activity tab shows only FHIR
    // Observations. File attachments shared during calls are persisted server-side
    // but are not visible in the in-call Activity panel or dialogue replay.
    debugPrint('VideoConsultation: persisting Communication to Medplum — '
        'not displayed in Activity tab (Observations only)');
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

  // ── Activity panel (DraggableScrollableSheet in Stack) ───────────────────────
  // FIX 4: Chat tab removed — Activity observations only.
  Widget _buildChatPanel() {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.45,
        minChildSize: 0.0,
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
                // Header — swipe down anywhere on the header row to dismiss
                GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! > 200) {
                      _sheetController.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                    child: Row(
                      children: [
                        Text(
                          AppStrings.of(_lang, 'call.activity_title'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _sheetController.animateTo(
                            0.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Activity observations only
                Expanded(child: _buildActivityTab()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Activity tab content ───────────────────────────────────────────────────
  Widget _buildActivityTab() {
    if (!_activityLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5BA4CF)),
      );
    }
    if (_activityObservations.isEmpty) {
      return Center(
        child: Text(
          AppStrings.of(_lang, 'call.activity_empty'),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _activityObservations.length,
      itemBuilder: (_, i) => _buildActivityObsCard(_activityObservations[i]),
    );
  }

  Widget _buildActivityObsCard(Map<String, dynamic> obs) {
    final isoDate   = obs['effectiveDateTime'] as String? ?? '';
    final dateLabel = isoDate.isNotEmpty ? DateFormatter.format(isoDate) : '';
    final val       = obs['valueString'] as String? ?? '';
    final summary   = val.length > 180 ? '${val.substring(0, 180)}…' : val;

    final exts = (obs['extension'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final catExt = exts
        .where((e) => FhirExtensionUtils.isSessionCategory(e['url'] as String? ?? ''))
        .firstOrNull;
    final cat       = catExt?['valueString'] as String?;
    final isMedical = cat == 'medical';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 4,
            spreadRadius: -1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateLabel,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isMedical
                      ? const Color(0xFFEBF4FB)
                      : const Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isMedical ? AppStrings.of(_lang, 'call.activity_medical') : AppStrings.of(_lang, 'call.activity_other'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMedical
                        ? const Color(0xFF5BA4CF)
                        : const Color(0xFF40484E),
                  ),
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              summary,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF191C1F),
                height: 1.4,
              ),
            ),
          ],
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

          // Layer 5.5 — Peer-left overlay (shown when remote peer disconnects).
          // Fully opaque black so the frozen last video frame is completely hidden.
          if (_peerLeft)
            Container(
              color: Colors.black,
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
            // Full-screen transparent barrier: tapping anywhere outside the
            // sheet dismisses it. The sheet itself is on top in the Stack so
            // taps on the sheet content are not intercepted by this barrier.
            Positioned.fill(
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
                  color: Colors.white.withOpacity(0.3),
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
                  color: Colors.black.withOpacity(0.5),
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
                    .withOpacity(opacities[i]),
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
              color: Colors.white.withOpacity(0.85),
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
                color:      Colors.black.withOpacity(0.25),
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
    // FIX 4: Chat removed — strip now toggles the Activity panel only.
    return Semantics(
      label: AppStrings.of(_lang, 'call.tab_activity'),
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
                icon: const Icon(Icons.attach_file, size: 32, color: Color(0xFF5BA4CF)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _chatOpen = !_chatOpen),
                  child: Text(
                    AppStrings.of(_lang, 'call.tab_activity'),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const Icon(Icons.expand_less, color: Color(0xFF5BA4CF), size: 28),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layer 6: Top header ────────────────────────────────────────────────────

  Widget _buildTopHeader() {
    final shadow = Shadow(
      color:      Colors.black.withOpacity(0.6),
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
                  AppStrings.of(_lang, 'video.header').replaceAll(
                    '{doctorName}',
                    ref.read(medicalSessionProvider).lastDoctorName ??
                        AppStrings.of(_lang, 'role.doctor'),
                  ),
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
