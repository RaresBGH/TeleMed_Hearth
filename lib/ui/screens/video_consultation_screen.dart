// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/language_provider.dart';

class VideoConsultationScreen extends ConsumerStatefulWidget {
  const VideoConsultationScreen({super.key});

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

  // ── Screen state ───────────────────────────────────────────────────────────
  bool     _isMuted      = false;
  bool     _isConnecting = true;

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
    _initAnimController();
    _initWebRTC();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _animController.dispose();
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
        ],
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

      // Fires when the remote peer adds a stream (requires real signaling).
      _peerConnection!.onAddStream = (stream) {
        if (mounted) setState(() => _remoteRenderer.srcObject = stream);
      };

      // Start call duration counter.
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _callDuration += const Duration(seconds: 1));
        }
      });

      debugPrint('WebRTC initialized — signaling not yet connected');
    } catch (e) {
      debugPrint('VideoConsultationScreen._initWebRTC error: $e');
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _toggleMute() {
    final newMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !newMuted; // enabled = true when NOT muted
    });
    setState(() => _isMuted = newMuted);
  }

  void _endCall() {
    // WebRTC cleanup happens in dispose() when the widget is removed.
    ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.home);
  }

  void _onAttachDocument() { /* future: file picker → send to doctor */ }
  void _onSendMessage()    { /* future: text/document message */ }

  void _showChatPanel(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(
          child: Text(
            'Chat și documente — în curând',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: Colors.black,
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

          // Layer 6 — Top header (over video, SafeArea-wrapped)
          _buildTopHeader(),
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
      label: _isMuted ? 'Activează microfonul' : 'Dezactivează microfonul',
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
      label: 'Închide consultația',
      child: GestureDetector(
        onTap: _endCall,
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
      label: 'Deschide chat și documente',
      child: GestureDetector(
        onTap: () => _showChatPanel(context),
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
                onPressed: _onAttachDocument,
                icon: const Icon(
                  Icons.attach_file,
                  size:  32,
                  color: Colors.grey,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showChatPanel(context),
                  child: const Text(
                    'Mesaj sau document...',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                onPressed: _onSendMessage,
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
