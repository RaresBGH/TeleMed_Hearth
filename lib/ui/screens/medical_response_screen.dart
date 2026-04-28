// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors
// Design reference: stitch_telemed_k/chat_screen/screen.png + code.html

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/chat_message.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/camera_service.dart';

// ── Design tokens (matches Stitch palette from code.html) ─────────────────────

const Color _brandBlue    = Color(0xFF5BA4CF);
const Color _bgPage       = Color(0xFFF5F7FA);
const Color _onSurface    = Color(0xFF191C1F);
const Color _muted        = Color(0xFF70787F);
const Color _outlineVar   = Color(0xFFBFC7CF);
const Color _aiBubbleBg   = Color(0x1A5BA4CF); // brand-blue/10
const Color _surfContainer = Color(0xFFECEEF2);

// ── Screen ────────────────────────────────────────────────────────────────────

class MedicalResponseScreen extends ConsumerStatefulWidget {
  final String initialResponse;
  final bool isEmergency;

  const MedicalResponseScreen({
    super.key,
    required this.initialResponse,
    required this.isEmergency,
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

  bool _isRecording   = false;
  bool _isProcessing  = false;
  bool _isFinalizing  = false;

  @override
  void initState() {
    super.initState();
    // Seed chat with the default follow-up prompt from the AI.
    _messages.add(ChatMessage(
      role: 'ai',
      text: 'Aveți și alte simptome pe care doriți să le descrieți?',
      timestamp: DateTime.now(),
    ));
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _onBack() {
    // reset() → SessionState.idle → AppNavigationNotifier listener → AppRoute.home
    ref.read(medicalSessionProvider.notifier).reset();
  }

  // ── Scroll ──────────────────────────────────────────────────────────────────

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
            : 'Nu am înțeles. Vă rog reformulați.';
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
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
            text: '🎤 Mesaj vocal',
            timestamp: DateTime.now()));
      });
      _scrollToBottom();

      if (wavPath.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      try {
        final result =
            await ref.read(aiEngineServiceProvider).evaluateAudio(File(wavPath));
        audioService.deleteWavFile(wavPath);
        _appendAiResponse(result);
      } catch (_) {
        audioService.deleteWavFile(wavPath);
        if (mounted) setState(() => _isProcessing = false);
      }
    } else {
      final hasPermission = await audioService.requestPermission();
      if (!mounted) return;
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permisiunea pentru microfon este necesară.',
              style: TextStyle(fontSize: 16)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Permisiunea pentru cameră este necesară.',
            style: TextStyle(fontSize: 16)),
      ));
      return;
    }

    final imagePath = await cameraService.captureImage();
    if (!mounted || imagePath == null) return;

    setState(() {
      _isProcessing = true;
      // Show patient's own bubble immediately while AI processes.
      _messages.add(ChatMessage(
          role: 'patient',
          text: '📷 Fotografie',
          timestamp: DateTime.now()));
    });
    _scrollToBottom();

    try {
      final result =
          await ref.read(aiEngineServiceProvider).evaluateMedia(File(imagePath));
      cameraService.deleteTempFile(imagePath);
      _appendAiResponse(result);
    } catch (_) {
      cameraService.deleteTempFile(imagePath);
      if (mounted) setState(() => _isProcessing = false);
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
          await ref.read(aiEngineServiceProvider).evaluateText(text);
      _appendAiResponse(result);
    } catch (_) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Emergency chip ───────────────────────────────────────────────────────────

  Future<void> _onEmergencyTap() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Finalize dialog ───────────────────────────────────────────────────────────

  Future<void> _onFinalize() async {
    if (_isFinalizing) return;
    setState(() => _isFinalizing = true);

    try {
      await ref
          .read(medicalSessionProvider.notifier)
          .finalizeConsultation(List.unmodifiable(_messages));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dialogul a fost salvat în dosarul medical',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;

      // Explicit patient finalization — navigate home, do not auto-save again.
      ref.read(medicalSessionProvider.notifier).reset();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la salvare: $e',
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: _bgPage,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  _buildTriageCard(),
                  const SizedBox(height: 24),
                  _buildSectionDivider(),
                  const SizedBox(height: 16),
                  ..._messages.map(_buildBubble),
                  if (_isProcessing) _buildTypingIndicator(),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _brandBlue),
        onPressed: _onBack,
      ),
      titleSpacing: 0,
      title: const Text(
        'Asistentul tău medical',
        style: TextStyle(
          color: _brandBlue,
          fontSize: 20,
          fontWeight: FontWeight.bold,
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
              const Text(
                'Analiza simptomelor',
                style: TextStyle(
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
                : 'Simptomele dumneavoastră au fost înregistrate.',
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emergency, color: Color(0xFFBA1A1A), size: 16),
              SizedBox(width: 6),
              Text(
                'URGENȚĂ - Sunați 112',
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16),
          SizedBox(width: 6),
          Text(
            'Prioritate normală',
            style: TextStyle(
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
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE0E2E7))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'CONTINUAȚI CONVERSAȚIA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE0E2E7))),
      ],
    );
  }

  // ── Chat bubbles ──────────────────────────────────────────────────────────────

  Widget _buildBubble(ChatMessage msg) {
    final bool isAi = msg.role == 'ai';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isAi ? _onSurface : Colors.white,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
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
          child: const _TypingDots(),
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
                    : const Text(
                        'Finalizează Dialogul',
                        style: TextStyle(
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
          // Attachment stub
          _InputIconButton(
            icon: Icons.attach_file,
            onTap: () {},
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
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Scrieți sau vorbiți...',
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
