// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/practitioner_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/chat_message.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/providers/my_doctor_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/language_toggle.dart';
import 'appointments_screen.dart';
import 'medical_response_screen.dart';
import 'specialists_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _bg         = Color(0xFFF7F9FE);
const Color _cardBg     = Color(0xFFFFFFFF);
const Color _surfLow    = Color(0xFFF2F4F8);
const Color _brand      = Color(0xFF5BA4CF);
const Color _onSurface  = Color(0xFF191C1F);
const Color _onSurfaceV = Color(0xFF40484E);
const Color _outline    = Color(0xFF70787F);

/// Parametrized doctor profile screen used by the family doctor tab (A2)
/// and future specialist sub-screens (A4).
///
/// [showBackButton]    — true when pushed as a sub-screen (e.g. specialist).
/// [showSpecialtyPicker] — true for family doctor view; hides section for specialists.
/// [doctorName]        — displayed in the card and injected into the preseed message.
/// [doctorSpecialty]   — null falls back to AppStrings doctor.family_specialty.
/// [practitionerRef]   — FHIR Practitioner ID (null until Medplum wired).
class DoctorProfileScreen extends ConsumerWidget {
  final bool showBackButton;
  final bool showSpecialtyPicker;
  final String doctorName;
  final String? doctorSpecialty;
  final String? practitionerRef;

  const DoctorProfileScreen({
    super.key,
    this.showBackButton      = false,
    this.showSpecialtyPicker = true,
    this.doctorName          = Practitioners.familyDoctorName,
    this.doctorSpecialty,
    this.practitionerRef,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang          = ref.watch(languageProvider);
    final specialty     = doctorSpecialty ?? AppStrings.of(lang, 'doctor.family_specialty');
    final encounterAsync = ref.watch(mostRecentEncounterProvider);
    final medAsync      = ref.watch(mostRecentMedicationProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context, ref, lang),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildDoctorCard(context, ref, lang, specialty),
                    const SizedBox(height: 20),
                    if (showSpecialtyPicker) ...[
                      _buildConsultationsSection(context, ref, lang),
                      const SizedBox(height: 20),
                    ],
                    _buildInfoCard(lang, encounterAsync, medAsync),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          if (!showBackButton) const AppBottomNavBar(),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, WidgetRef ref, String lang) {
    return AppBar(
      backgroundColor: _cardBg,
      elevation: 0,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      leadingWidth: showBackButton ? 64 : 0,
      leading: showBackButton
          ? Semantics(
              button: true,
              label: AppStrings.of(lang, 'profil.back_sem'),
              child: InkWell(
                onTap: () {
                  // TODO(A4): When specialist sub-screens use Navigator.push,
                  // Navigator.pop() works correctly. For now fall back to flat nav.
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    ref
                        .read(appNavigationProvider.notifier)
                        .navigateTo(AppRoute.myDoctor);
                  }
                },
                child: const SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(Icons.arrow_back, color: _onSurface, size: 26),
                ),
              ),
            )
          : null,
      title: Text(
        AppStrings.of(lang, 'nav.doctor'),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _brand,
        ),
      ),
      centerTitle: true,
      actions: const [
        LanguageToggle(),
        SizedBox(width: 16),
      ],
    );
  }

  // ── Doctor card ───────────────────────────────────────────────────────────

  Widget _buildDoctorCard(
      BuildContext context, WidgetRef ref, String lang, String specialty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 24,
            spreadRadius: -4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E8ED),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _cardBg,
                    width: 4,
                  ),
                ),
                child: const Icon(Icons.person, size: 44, color: Color(0xFF8A8E95)),
              ),
              // Green online dot — keeps green for availability semantics per DESIGN.md
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    shape: BoxShape.circle,
                    border: Border.all(color: _cardBg, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            doctorName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _onSurface,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Specialty
          Text(
            specialty,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _onSurfaceV,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // "Disponibil acum" chip — stays GREEN (availability status, not validation)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  AppStrings.of(lang, 'doctor.available_now'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons — DESIGN.md: min 64dp height, 12dp radius, NOT pill-shaped
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_outlined,
                  label: AppStrings.of(lang, 'doctor.message_btn'),
                  onTap: () {
                    final preseed =
                        AppStrings.of(lang, 'doctor.message_preseed')
                            .replaceAll('[name]', doctorName);
                    if (showBackButton) {
                      // Specialist sub-screen: push so back returns here.
                      // TODO(medplum): scope thread to practitionerRef
                      if (!context.mounted) return;
                      // Set doctorName in state for finalizeConsultation attribution.
                      ref.read(medicalSessionProvider.notifier)
                          .startWithPreseed(preseed, doctorName: doctorName);
                      final msg = ChatMessage(
                        role: 'patient',
                        text: preseed,
                        timestamp: DateTime.now(),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicalResponseScreen(
                            initialResponse: AppStrings.of(
                                lang, 'chat.default_response'),
                            isEmergency: false,
                            initialMessages: [msg],
                          ),
                        ),
                      );
                    } else {
                      // Family doctor tab: push via Navigator so back returns
                      // here; initialPrompt auto-triggers AI inference.
                      ref
                          .read(medicalSessionProvider.notifier)
                          .startWithPreseed(preseed, doctorName: doctorName);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicalResponseScreen(
                            initialResponse: AppStrings.of(
                                lang, 'chat.default_response'),
                            isEmergency: false,
                            initialPrompt: preseed,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.calendar_month_outlined,
                  label: AppStrings.of(lang, 'doctor.book_appointment'),
                  onTap: () {
                    if (showBackButton) {
                      // Specialist sub-screen: push with doctor context so the
                      // calendar is scoped and booking pre-fills doctor info.
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentsScreen(
                            practitionerRef: practitionerRef,
                            doctorName:      doctorName,
                            doctorSpecialty: specialty,
                          ),
                        ),
                      );
                    } else {
                      // Family doctor tab: flat nav.
                      ref
                          .read(appNavigationProvider.notifier)
                          .navigateTo(AppRoute.appointments);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Specialty consultations section ───────────────────────────────────────

  Widget _buildConsultationsSection(
      BuildContext context, WidgetRef ref, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            AppStrings.of(lang, 'doctor.consultations_section'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _outline,
              letterSpacing: 1.2,
            ),
          ),
        ),
        // Specialty picker button — DESIGN.md: min 80dp touch target
        Semantics(
          button: true,
          label: AppStrings.of(lang, 'doctor.specialty_nav'),
          child: InkWell(
            onTap: () {
              // Always push so back button returns to this screen (BUG 7 fix).
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SpecialistsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 16,
                    spreadRadius: -4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0x1A5BA4CF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.grid_view, color: _brand, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      AppStrings.of(lang, 'doctor.specialty_nav'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _onSurface,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _brand, size: 28),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── FHIR info rows card ───────────────────────────────────────────────────

  Widget _buildInfoCard(
    String lang,
    AsyncValue<Map<String, dynamic>?> encounterAsync,
    AsyncValue<Map<String, dynamic>?> medAsync,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            spreadRadius: -4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1 — last consultation
          _buildInfoRow(
            icon: Icons.history,
            label: AppStrings.of(lang, 'doctor.last_consult'),
            valueWidget: encounterAsync.when(
              data: (data) {
                if (data == null) {
                  return Text(
                    AppStrings.of(lang, 'doctor.no_consult'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500, color: _onSurface),
                  );
                }
                final iso = data['period']?['start'] as String? ?? '';
                final display = iso.isNotEmpty
                    ? DateFormatter.format(iso)
                    : AppStrings.of(lang, 'doctor.unknown_date');
                return Text(
                  display,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500, color: _onSurface),
                );
              },
              loading: () => const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
              ),
              error: (_, __) => Text(
                AppStrings.of(lang, 'doctor.error'),
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          ),
          // Spacer between rows — no 1px dividers per DESIGN.md
          Container(height: 1, color: _surfLow),
          // Row 2 — active prescription
          _buildInfoRow(
            icon: Icons.medication_outlined,
            label: AppStrings.of(lang, 'doctor.active_prescription'),
            valueWidget: medAsync.when(
              data: (data) {
                if (data == null) {
                  return Text(
                    AppStrings.of(lang, 'doctor.no_prescription'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500, color: _onSurface),
                  );
                }
                final text = data['medicationCodeableConcept']?['text'] as String?
                    ?? AppStrings.of(lang, 'doctor.treatment');
                return Text(
                  text,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500, color: _onSurface),
                );
              },
              loading: () => const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
              ),
              error: (_, __) => Text(
                AppStrings.of(lang, 'doctor.error'),
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required Widget valueWidget,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: _onSurfaceV, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _onSurfaceV,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                valueWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private widget — outlined action button ───────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _brand, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _brand, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _brand,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
