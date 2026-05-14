// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/practitioner_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/ai_engine_service.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/ai_ready_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/providers/my_doctor_provider.dart';
import '../../core/providers/patient_history_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/dialog_detail_sheet.dart';
import '../widgets/language_toggle.dart';

// ── Design tokens (Horizon/Stitch palette) ────────────────────────────────────
const Color _bg         = Color(0xFFF7F9FE);
const Color _cardBg     = Color(0xFFFFFFFF);
const Color _cardBorder = Color(0xFFECEEF2);
const Color _onSurface  = Color(0xFF191C1F);
const Color _onSurfaceV = Color(0xFF40484E);
const Color _brand      = Color(0xFF5BA4CF);
const Color _greenBg    = Color(0xFFE6F4EA);
const Color _greenFg    = Color(0xFF137333);
const Color _amberBg    = Color(0xFFFEF9C3);
const Color _amberFg    = Color(0xFFCA8A04);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final lang        = ref.watch(languageProvider);
    final firstName   = ref.watch(patientAuthProvider).patientFirstName;
    final bool aiReady = ref.watch(aiReadyProvider).maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    final historyAsync = ref.watch(patientHistoryProvider);
    final medAsync     = ref.watch(mostRecentMedicationProvider);
    final apptAsync    = ref.watch(appointmentsProvider);

    // Invalidate caches when a triage session completes.
    ref.listen<MedicalSessionState>(medicalSessionProvider, (previous, current) {
      if (current.sessionState == SessionState.idle &&
          previous?.sessionState != SessionState.idle) {
        ref.invalidate(patientHistoryProvider);
      }
    });

    // Find the earliest upcoming booked appointment for the status card.
    // Returns [text, specialty] so both can be shown on the card.
    final List<String?> nextApptData = apptAsync.maybeWhen(
      data: (appts) {
        final now = DateTime.now();
        Map<String, dynamic>? next;
        for (final appt in appts) {
          // Accept 'booked' or 'confirmed' (case-insensitive) — some Medplum
          // appointments arrive with 'confirmed' status after creation.
          final apptStatus = (appt['status'] as String? ?? '').toLowerCase();
          if (apptStatus != 'booked' && apptStatus != 'confirmed') continue;
          final dt = DateTime.tryParse(
              appt['start'] as String? ?? '')?.toLocal();
          // Include appointments within the join window (started up to 2h ago).
          if (dt == null || !dt.isAfter(now.subtract(const Duration(hours: 2)))) continue;
          if (next == null) {
            next = appt;
          } else {
            final prevDt = DateTime.tryParse(
                next['start'] as String? ?? '')?.toLocal();
            if (prevDt != null && dt.isBefore(prevDt)) next = appt;
          }
        }
        if (next == null) return [null, null];
        final dateStr = DateFormatter.format(
            next['start'] as String, includeTime: true);
        // Extract doctor name and specialty from "type · specialty · doctorName".
        final parts = ((next['description'] as String?) ?? '').split(' · ');
        final doctorName = parts.length >= 2 ? parts.last : null;
        final specialty  = parts.length >= 3 ? parts[1] : null;
        final text = doctorName != null ? '$dateStr · $doctorName' : dateStr;
        return [text, specialty];
      },
      orElse: () => [null, null],
    );
    final String? nextApptText      = nextApptData[0];
    final String? nextApptSpecialty = nextApptData[1];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: const [
          LanguageToggle(),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Patient header ─────────────────────────────────────
                    _buildHeader(lang, firstName, aiReady),
                    const SizedBox(height: 24),

                    // ── Health summary card ────────────────────────────────
                    historyAsync.when(
                      data: (data) => _buildHealthCard(context, lang, data),
                      loading: () => _buildHealthCardShimmer(),
                      error: (_, __) => _buildHealthCard(context, lang, const []),
                    ),
                    const SizedBox(height: 16),

                    // ── Quick status row ───────────────────────────────────
                    medAsync.when(
                      data: (med) => _buildQuickStatusRow(lang, med, nextApptText,
                          nextApptSpecialty: nextApptSpecialty,
                          onApptTap: () => ref.read(appNavigationProvider.notifier)
                              .navigateTo(AppRoute.appointments)),
                      loading: () => _buildQuickStatusRow(lang, null, nextApptText,
                          nextApptSpecialty: nextApptSpecialty,
                          onApptTap: () => ref.read(appNavigationProvider.notifier)
                              .navigateTo(AppRoute.appointments)),
                      error: (_, __) => _buildQuickStatusRow(lang, null, nextApptText,
                          nextApptSpecialty: nextApptSpecialty,
                          onApptTap: () => ref.read(appNavigationProvider.notifier)
                              .navigateTo(AppRoute.appointments)),
                    ),
                    const SizedBox(height: 24),

                    // ── Recent activity ────────────────────────────────────
                    historyAsync.when(
                      data: (data) => _buildRecentActivity(context, lang, data),
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(color: _brand),
                      )),
                      error: (_, __) => _buildRecentActivity(context, lang, const []),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // ── Primary CTA ────────────────────────────────────────────────
          _buildCta(lang),

          // ── Bottom nav ──────────────────────────────────────────────────
          const AppBottomNavBar(),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(String lang, String? firstName, bool aiReady) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final avatarBytes = ref.watch(patientAvatarProvider);
            return Semantics(
              button: true,
              label: AppStrings.of(lang, 'nav.profile'),
              child: GestureDetector(
                onTap: () => ref.read(appNavigationProvider.notifier)
                    .navigateTo(AppRoute.patientProfile),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD0D3D8),
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarBytes != null
                      ? Image.memory(avatarBytes, fit: BoxFit.cover)
                      : const Icon(Icons.person, size: 26,
                          color: Color(0xFF8A8E95)),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.of(lang, 'dashboard.greeting_small'),
                style: const TextStyle(
                  fontSize: 14,
                  color: _onSurfaceV,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (firstName != null && firstName.isNotEmpty)
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _onSurface,
                    height: 1.1,
                  ),
                ),
              const SizedBox(height: 6),
              _AiStatusPill(isReady: aiReady, lang: lang),
            ],
          ),
        ),
      ],
    );
  }

  // ── Health summary card ───────────────────────────────────────────────────

  Widget _buildHealthCardShimmer() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      child: const Center(child: CircularProgressIndicator(color: _brand)),
    );
  }

  Widget _buildHealthCard(
    BuildContext context,
    String lang,
    List<Map<String, dynamic>> data,
  ) {
    final conditions = data.where((e) => e['resourceType'] == 'Condition').toList();
    final conditionCode = conditions.isNotEmpty
        ? (conditions.first['code'] as Map<String, dynamic>? ?? const {})
        : const <String, dynamic>{};
    final conditionName = conditionCode['text'] as String? ??
        AppStrings.of(lang, 'dashboard.no_condition');

    final observations = data.where((e) => e['resourceType'] == 'Observation').toList();
    String lastDialogText = AppStrings.of(lang, 'dashboard.no_dialog');
    if (observations.isNotEmpty) {
      final iso = observations.first['effectiveDateTime'] as String? ??
                  observations.first['recordedDate'] as String? ?? '';
      if (iso.isNotEmpty) lastDialogText = DateFormatter.format(iso);
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.of(lang, 'dashboard.health_title').toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _onSurfaceV,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, color: _brand, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  conditionName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Text(
              '${AppStrings.of(lang, 'dashboard.last_dialog')} $lastDialogText',
              style: const TextStyle(fontSize: 14, color: _onSurfaceV),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFE0E2E7), thickness: 1, height: 1),
          ),
          GestureDetector(
            onTap: () => ref.read(appNavigationProvider.notifier)
                .navigateTo(AppRoute.myDoctor),
            child: Row(
              children: [
                const Icon(Icons.medical_services, color: _onSurfaceV, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${AppStrings.of(lang, 'dashboard.doctor_label')} ${Practitioners.familyDoctorName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _onSurface,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: _onSurfaceV, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick status row ──────────────────────────────────────────────────────

  Widget _buildQuickStatusRow(
      String lang, Map<String, dynamic>? med, String? nextApptText,
      {String? nextApptSpecialty, VoidCallback? onApptTap}) {
    final medText = med != null
        ? (med['medicationCodeableConcept']?['text'] as String? ??
           AppStrings.of(lang, 'doctor.treatment'))
        : AppStrings.of(lang, 'dashboard.no_active_treatment');

    return Row(
      children: [
        Expanded(
          child: _StatusCard(
            icon: Icons.calendar_month,
            label: AppStrings.of(lang, 'dashboard.appointments_title'),
            value: nextApptText ?? AppStrings.of(lang, 'dashboard.no_appt'),
            subtitle: nextApptSpecialty,
            onTap: onApptTap ?? () {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatusCard(
            icon: Icons.medication,
            label: AppStrings.of(lang, 'dashboard.active_treatment'),
            value: medText,
          ),
        ),
      ],
    );
  }

  // ── Recent activity ───────────────────────────────────────────────────────

  Widget _buildRecentActivity(
    BuildContext context,
    String lang,
    List<Map<String, dynamic>> data,
  ) {
    final observations = data
        .where((e) => e['resourceType'] == 'Observation')
        .take(2)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.of(lang, 'dashboard.recent_activity').toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _onSurfaceV,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (observations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                AppStrings.of(lang, 'dashboard.no_activity'),
                style: const TextStyle(fontSize: 15, color: _onSurfaceV),
              ),
            ),
          )
        else
          ...observations.map((item) {
            final iso = item['effectiveDateTime'] as String? ??
                        item['recordedDate'] as String? ?? '';
            final dateStr = iso.isNotEmpty ? DateFormatter.format(iso) : '';
            final status  = item['status'] as String?;
            // label is always overridden by AppStrings in _ActivityItem below

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ActivityItem(
                title: AppStrings.of(lang, 'dashboard.triage_dialog'),
                subtitle: '$dateStr · ${AppStrings.of(lang, 'dashboard.priority_normal')}',
                onTap: () => DialogDetailSheet.show(
                  context,
                  ref,
                  lang,
                  item,
                  dateStr,
                  status,
                ),
              ),
            );
          }),
      ],
    );
  }

  // ── Primary CTA ───────────────────────────────────────────────────────────

  Widget _buildCta(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: () =>
              ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.home),
          style: ElevatedButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            AppStrings.of(lang, 'dashboard.cta_btn'),
            style: GoogleFonts.lexend(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

}

// ── Private widgets ────────────────────────────────────────────────────────────

class _AiStatusPill extends StatelessWidget {
  final bool isReady;
  final String lang;

  const _AiStatusPill({required this.isReady, required this.lang});

  @override
  Widget build(BuildContext context) {
    final String? initError = isReady ? null : AiEngineService.lastInitError;
    final bool hasError = initError != null;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isReady ? _greenBg : _amberBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isReady ? '●' : (hasError ? '✕' : '⟳'),
            style: TextStyle(
              fontSize: 10,
              color: isReady ? _greenFg : _amberFg,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isReady
                ? AppStrings.of(lang, 'home.ai_ready')
                : (hasError ? 'AI error — tap for info' : AppStrings.of(lang, 'home.ai_loading')),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isReady ? _greenFg : _amberFg,
            ),
          ),
        ],
      ),
    );

    if (!hasError) return pill;

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI Engine Error'),
          content: SingleChildScrollView(
            child: SelectableText(AiEngineService.lastInitError ?? ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
      child: pill,
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 110),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0x1A5BA4CF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, color: _brand, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _onSurfaceV,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _onSurface,
              height: 1.2,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: _onSurfaceV,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    ), // Container
    ); // GestureDetector
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          constraints: const BoxConstraints(minHeight: 72),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cardBorder),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 8,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _onSurfaceV,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _brand, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
