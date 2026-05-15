// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/constants/practitioner_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/fhir_extension_utils.dart';
import 'video_consultation_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _bg       = Color(0xFFF9F9F9);
const Color _cardBg   = Color(0xFFFFFFFF);
const Color _surfLow  = Color(0xFFF3F3F3);
const Color _brand    = Color(0xFF5BA4CF);
const Color _onSurface = Color(0xFF191C1F);
const Color _onSurfaceV = Color(0xFF40484E);
const Color _errorRed = Color(0xFFAB1118);

/// Compound consent + waiting room screen (A5).
///
/// STATE A (_consentGiven == false): patient reads and accepts consent terms.
///   Source: stitch_telemed_k/sala_de_a_teptare_i_acord_waiting_room_and_consent/
/// STATE B (_consentGiven == true): post-consent buffer zone, local camera preview.
///   Source: stitch_telemed_k/waiting_room/
///
/// [appointmentId] — optional; passed from appointments_screen for future
///   signaling integration.
/// [doctorName] — doctor displayed in header and notified message.
class WaitingRoomScreen extends ConsumerStatefulWidget {
  final String? appointmentId;
  final String  doctorName;
  /// Specialist specialty string (e.g. 'Cardiologie'). Displayed in the next task.
  final String? doctorSpecialty;

  const WaitingRoomScreen({
    super.key,
    this.appointmentId,
    this.doctorName = Practitioners.familyDoctorName,
    this.doctorSpecialty,
  });

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {

  bool _consentGiven           = false;
  bool _micMuted               = false;
  bool _videoOff               = false;
  bool _privateSpaceConfirmed  = false;

  // ── Pulsing connection dot animation ──────────────────────────────────────
  late AnimationController _pulseController;

  // ── Local camera (STATE B) ────────────────────────────────────────────────
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool          _rendererReady = false;
  MediaStream?  _localStream;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _localStream?.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  // ── Local camera init (called on consent) ─────────────────────────────────
  Future<void> _initLocalCamera() async {
    try {
      await _localRenderer.initialize();
      final stream = await navigator.mediaDevices.getUserMedia(
          {'video': true, 'audio': true});
      if (!mounted) {
        stream.getTracks().forEach((t) => t.stop());
        return;
      }
      _localRenderer.srcObject = stream;
      _localStream = stream;
      setState(() => _rendererReady = true);
    } catch (e) {
      debugPrint('Camera init failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          AppStrings.of(ref.read(languageProvider), 'error.camera_unavailable'))));
    }
  }

  void _onConsentGiven() {
    setState(() => _consentGiven = true);
    _initLocalCamera().catchError((e) {
      debugPrint('Camera init error: $e');
    });
  }

  void _toggleMic() {
    final newMuted = !_micMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !newMuted);
    setState(() => _micMuted = newMuted);
  }

  void _toggleVideo() {
    final newOff = !_videoOff;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !newOff);
    setState(() => _videoOff = newOff);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _consentGiven
            ? _buildWaitingState(context, lang)
            : _buildConsentState(context, lang),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE A — Consent
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildConsentState(BuildContext context, String lang) {
    return SafeArea(
      key: const ValueKey('consent'),
      child: Column(
        children: [
          _buildConsentHeader(lang),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.of(lang, 'waiting.connecting')
                        .replaceAll('{doctorName}', widget.doctorName),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _onSurface,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _build3DotLoader(),
                  const SizedBox(height: 32),
                  _buildConsentCard(lang),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildConsentCTAs(context, lang),
        ],
      ),
    );
  }

  // Custom header for consent state
  Widget _buildConsentHeader(String lang) {
    return Container(
      color: _surfLow,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Doctor avatar
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.grey, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.of(lang, 'waiting.clinic'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: _onSurfaceV,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.doctorName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _onSurface,
                  ),
                ),
                if (widget.doctorSpecialty != null &&
                    widget.doctorSpecialty!.isNotEmpty)
                  Text(
                    widget.doctorSpecialty!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _onSurfaceV,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          // Pulsing green connection dot — STAYS GREEN (connection/availability status)
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Container(
                    width: 10 + 18 * _pulseController.value,
                    height: 10 + 18 * _pulseController.value,
                    decoration: BoxDecoration(
                      color: Colors.green.shade500.withOpacity(
                        0.65 * (1 - _pulseController.value),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3-dot loading indicator (#5BA4CF — replaces Stitch green)
  Widget _build3DotLoader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 12, height: 12,
            decoration: BoxDecoration(
                color: _brand.withOpacity(0.4), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Container(width: 12, height: 12,
            decoration: BoxDecoration(
                color: _brand.withOpacity(0.7), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Container(width: 12, height: 12,
            decoration: const BoxDecoration(color: _brand, shape: BoxShape.circle)),
      ],
    );
  }

  // Consent card (white, no 1px border, left accent via shadow+bg)
  Widget _buildConsentCard(String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        // Ghost shadow per DESIGN.md — no 1px border
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1A1C1C),
            blurRadius: 40,
            spreadRadius: -4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel, color: _brand, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.of(lang, 'waiting.consent_title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(lang, 'waiting.info'),
            style: const TextStyle(
              fontSize: 16,
              color: _onSurfaceV,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(lang, 'waiting.consent_text')
                .replaceAll('{doctorName}', widget.doctorName),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: _onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildConsentBullet(AppStrings.of(lang, 'waiting.consent_1')),
          const SizedBox(height: 12),
          _buildConsentBullet(AppStrings.of(lang, 'waiting.consent_2')),
          const SizedBox(height: 12),
          _buildConsentBullet(AppStrings.of(lang, 'waiting.consent_3')),
        ],
      ),
    );
  }

  Widget _buildConsentBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // check_circle in #5BA4CF — replaces Stitch green
        const Icon(Icons.check_circle, color: _brand, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, color: _onSurfaceV, height: 1.4),
          ),
        ),
      ],
    );
  }

  // CTA footer for STATE A
  Widget _buildConsentCTAs(BuildContext context, String lang) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Sunt de acord" — min 80dp, #5BA4CF, arrow icon
            Semantics(
              button: true,
              label: AppStrings.of(lang, 'waiting.agree_sem'),
              child: SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: _onConsentGiven,
                  icon: const Icon(Icons.arrow_forward, size: 26),
                  label: Text(
                    AppStrings.of(lang, 'waiting.agree_btn'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    // Ghost shadow per DESIGN.md
                    shadowColor: const Color(0x0F1A1C1C),
                    elevation: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // "Anulează" — min 72dp, outlined, #ab1118
            Semantics(
              button: true,
              label: AppStrings.of(lang, 'waiting.cancel_sem'),
              child: SizedBox(
                width: double.infinity,
                height: 72,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      ref.read(appNavigationProvider.notifier)
                          .navigateTo(AppRoute.dashboard);
                    }
                  },
                  icon: const Icon(Icons.close, color: _errorRed, size: 22),
                  label: Text(
                    AppStrings.of(lang, 'waiting.cancel_btn'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _errorRed,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _errorRed, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.of(lang, 'waiting.note'),
              style: const TextStyle(fontSize: 13, color: _onSurfaceV),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE B — Waiting Room buffer
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWaitingState(BuildContext context, String lang) {
    return SafeArea(
      key: const ValueKey('waiting'),
      child: Column(
        children: [
          _buildWaitingAppBar(context, lang),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  _buildVideoPreview(lang),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      AppStrings.of(lang, 'waiting.doctor_notified')
                          .replaceAll('{doctorName}', widget.doctorName),
                      style: const TextStyle(
                        fontSize: 16,
                        color: _onSurfaceV,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPrivateSpaceCheckbox(lang),
                  const SizedBox(height: 24),
                  _buildControlRow(lang),
                  const SizedBox(height: 20),
                  _buildEnterCallButton(lang),
                  const SizedBox(height: 12),
                  _buildActivityButton(lang),
                  const SizedBox(height: 12),
                  _buildWaitingCancelButton(context, lang),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Waiting state app bar
  Widget _buildWaitingAppBar(BuildContext context, String lang) {
    return AppBar(
      backgroundColor: _cardBg,
      elevation: 0,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      leadingWidth: 64,
      leading: InkWell(
        onTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            ref.read(appNavigationProvider.notifier)
                .navigateTo(AppRoute.dashboard);
          }
        },
        child: const SizedBox(
          width: 64,
          height: 64,
          child: Icon(Icons.arrow_back, color: _onSurface, size: 26),
        ),
      ),
      title: Text(
        AppStrings.of(lang, 'waiting.room_title'),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _onSurface,
        ),
      ),
      centerTitle: true,
    );
  }

  // 4:3 video container with status chips overlay
  Widget _buildVideoPreview(String lang) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              spreadRadius: -4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Local camera preview or black placeholder
            if (_rendererReady)
              RTCVideoView(_localRenderer, mirror: true)
            else
              Container(color: Colors.black),
            // Status chips overlay — emerald green STAYS (active/ok status)
            Positioned(
              top: 12,
              left: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusChip(
                    _micMuted ? Icons.mic_off : Icons.mic,
                    AppStrings.of(lang, _micMuted
                        ? 'waiting.mic_muted'
                        : 'waiting.mic_active'),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusChip(
                    Icons.wifi,
                    AppStrings.of(lang, 'waiting.internet_stable'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // Emerald green status chips STAY GREEN (active/ok indicators)
        color: Colors.green.shade600.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Private space checkbox — brand-blue tint, 2px border, full-row tappable.
  Widget _buildPrivateSpaceCheckbox(String lang) {
    return GestureDetector(
      onTap: () => setState(() => _privateSpaceConfirmed = !_privateSpaceConfirmed),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF4FB),
          border: Border.all(color: _brand, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: _privateSpaceConfirmed,
              onChanged: (v) =>
                  setState(() => _privateSpaceConfirmed = v ?? false),
              activeColor: _brand,
              checkColor: Colors.white,
              side: const BorderSide(color: _brand, width: 2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.of(lang, 'waiting.private_space'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Two 64dp circular control buttons
  Widget _buildControlRow(String lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: _micMuted ? Icons.mic_off : Icons.mic,
          label: AppStrings.of(lang, 'waiting.mute_btn'),
          onTap: _toggleMic,
        ),
        const SizedBox(width: 40),
        _buildControlButton(
          icon: _videoOff ? Icons.videocam_off : Icons.videocam,
          label: AppStrings.of(lang, 'waiting.video_off_btn'),
          onTap: _toggleVideo,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 64,
            height: 64,
            // Tonal background — NO border per DESIGN.md
            decoration: BoxDecoration(
              color: _surfLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _onSurface, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: _onSurfaceV),
        ),
      ],
    );
  }

  // "Intră în apel" — enabled only when _privateSpaceConfirmed
  Widget _buildEnterCallButton(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: _privateSpaceConfirmed
              ? () {
                  // pushReplacement removes WaitingRoom from the Navigator stack so
                  // pressing back from the call returns to AppointmentsScreen, not
                  // back here. Using flat nav would leave WaitingRoom on the stack,
                  // covering the VideoConsultationScreen.
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoConsultationScreen(
                        appointmentId: widget.appointmentId,
                      ),
                    ),
                  );
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _brand,
            disabledBackgroundColor: const Color(0xFFBFC7CF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text(
            AppStrings.of(lang, 'waiting.enter_call_btn'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // "See my recent activity" button — STATE B only
  Widget _buildActivityButton(String lang) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => unawaited(_showActivitySheet(lang)),
        icon: const Icon(Icons.history, color: _brand),
        label: Text(
          AppStrings.of(lang, 'waiting.activity_btn'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _brand,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _brand, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _showActivitySheet(String lang) async {
    final cnp = ref.read(loginCnpProvider);
    List<Map<String, dynamic>> observations;
    try {
      final all = await ref.read(fhirRepositoryProvider).getPatientHistory(cnp: cnp);
      observations = all
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
      if (observations.length > 5) observations = observations.sublist(0, 5);
    } catch (_) {
      observations = [];
    }

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppStrings.of(lang, 'waiting.activity_title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Content
            observations.isEmpty
                ? Expanded(
                    child: Center(
                      child: Text(
                        AppStrings.of(lang, 'waiting.activity_empty'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: _onSurfaceV,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: observations.length,
                      itemBuilder: (_, i) =>
                          _buildActivityCard(observations[i], lang),
                    ),
                  ),
            const Divider(height: 1),
            // Footer
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                AppStrings.of(lang, 'waiting.activity_footer'),
                style: const TextStyle(
                  fontSize: 13,
                  color: _onSurfaceV,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> obs, String lang) {
    final isoDate   = obs['effectiveDateTime'] as String? ?? '';
    final dateLabel = isoDate.isNotEmpty ? DateFormatter.format(isoDate) : '';
    final val       = obs['valueString'] as String? ?? '';
    final summary   = val.length > 200 ? '${val.substring(0, 200)}…' : val;

    final exts = (obs['extension'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final catExt = exts.where(
      (e) => FhirExtensionUtils.isSessionCategory(e['url'] as String? ?? ''),
    ).firstOrNull;
    final cat = catExt?['valueString'] as String?;
    final isMedical = cat == 'medical';

    final chipBg   = isMedical ? const Color(0xFFEBF4FB) : const Color(0xFFF2F4F8);
    final chipFg   = isMedical ? _brand : _onSurfaceV;
    final chipText = isMedical
        ? AppStrings.of(lang, 'waiting.activity_medical')
        : AppStrings.of(lang, 'waiting.activity_other');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            spreadRadius: -2,
            offset: Offset(0, 2),
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
                style: const TextStyle(fontSize: 13, color: _onSurfaceV),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  chipText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: chipFg,
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
                fontSize: 14,
                color: _onSurface,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // "Anulează" — NOT pill-shaped per DESIGN.md
  Widget _buildWaitingCancelButton(BuildContext context, String lang) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: TextButton(
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            ref.read(appNavigationProvider.notifier)
                .navigateTo(AppRoute.dashboard);
          }
        },
        style: TextButton.styleFrom(
          foregroundColor: _errorRed,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          AppStrings.of(lang, 'waiting.cancel_btn'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _errorRed,
          ),
        ),
      ),
    );
  }
}
