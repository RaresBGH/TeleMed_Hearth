// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/constants/practitioner_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/providers/patient_history_provider.dart';
import '../../core/utils/date_formatter.dart';
import 'waiting_room_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _bg         = Color(0xFFF7F9FE);
const Color _cardBg     = Color(0xFFFFFFFF);
const Color _surfLow    = Color(0xFFF2F4F8);
const Color _brand      = Color(0xFF5BA4CF);
const Color _onSurface  = Color(0xFF191C1F);
const Color _onSurfaceV = Color(0xFF40484E);
const Color _outline    = Color(0xFF70787F);
const Color _errorRed   = Color(0xFFAB1118);
const Color _surfHigh   = Color(0xFFE6E8ED);

// ── Available time slots — 09:00 to 23:30 in 30-minute increments (30 slots) ──
// Extended range covers evening hours for testing and flexibility.
const List<TimeOfDay> _availableSlots = [
  TimeOfDay(hour:  9, minute:  0),
  TimeOfDay(hour:  9, minute: 30),
  TimeOfDay(hour: 10, minute:  0),
  TimeOfDay(hour: 10, minute: 30),
  TimeOfDay(hour: 11, minute:  0),
  TimeOfDay(hour: 11, minute: 30),
  TimeOfDay(hour: 12, minute:  0),
  TimeOfDay(hour: 12, minute: 30),
  TimeOfDay(hour: 13, minute:  0),
  TimeOfDay(hour: 13, minute: 30),
  TimeOfDay(hour: 14, minute:  0),
  TimeOfDay(hour: 14, minute: 30),
  TimeOfDay(hour: 15, minute:  0),
  TimeOfDay(hour: 15, minute: 30),
  TimeOfDay(hour: 16, minute:  0),
  TimeOfDay(hour: 16, minute: 30),
  TimeOfDay(hour: 17, minute:  0),
  TimeOfDay(hour: 17, minute: 30),
  TimeOfDay(hour: 18, minute:  0),
  TimeOfDay(hour: 18, minute: 30),
  TimeOfDay(hour: 19, minute:  0),
  TimeOfDay(hour: 19, minute: 30),
  TimeOfDay(hour: 20, minute:  0),
  TimeOfDay(hour: 20, minute: 30),
  TimeOfDay(hour: 21, minute:  0),
  TimeOfDay(hour: 21, minute: 30),
  TimeOfDay(hour: 22, minute:  0),
  TimeOfDay(hour: 22, minute: 30),
  TimeOfDay(hour: 23, minute:  0),
  TimeOfDay(hour: 23, minute: 30),
];

class AppointmentsScreen extends ConsumerStatefulWidget {
  /// When non-null, only appointments for this practitioner are loaded,
  /// scoping the calendar to a single doctor (BUG 5 fix).
  final String? practitionerRef;

  /// Doctor name and specialty pre-fill the inline booking panel (BUG 2 fix).
  final String doctorName;
  final String? doctorSpecialty;

  /// When true, shows the "Request new appointment" CTA button.
  /// Hidden by default so the flat-nav all-appointments view is read-only.
  final bool showBookingButton;

  /// When non-null, used as the AppBar title instead of the default key.
  final String? screenTitle;

  const AppointmentsScreen({
    super.key,
    this.practitionerRef,
    this.doctorName        = Practitioners.familyDoctorName,
    this.doctorSpecialty,
    this.showBookingButton = false,
    this.screenTitle,
  });

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  DateTime _focusedDay              = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _appointments = [];
  bool _loading                     = true;
  bool _hasLoaded                   = false;
  bool _showBookingPanel             = false;
  TimeOfDay? _selectedSlot;
  bool _isSaving                    = false;

  @override
  void initState() {
    super.initState();
    // Safety guard — main() already calls this, but guard here too.
    unawaited(initializeDateFormatting('ro_RO', null));
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (_hasLoaded) return;
    final cnp = ref.read(loginCnpProvider);
    try {
      final data = await ref
          .read(fhirRepositoryProvider)
          .getAppointments(cnp: cnp, practitionerRef: widget.practitionerRef);
      if (!mounted) return;

      // Dart-side safety sort: upcoming ascending, past descending.
      final now    = DateTime.now();
      final sorted = List<Map<String, dynamic>>.from(data);
      sorted.sort((a, b) {
        final aDt = DateTime.tryParse(a['start'] as String? ?? '')?.toLocal();
        final bDt = DateTime.tryParse(b['start'] as String? ?? '')?.toLocal();
        final aUp = aDt != null && aDt.isAfter(now);
        final bUp = bDt != null && bDt.isAfter(now);
        if (aUp && bUp) return aDt.compareTo(bDt);
        if (!aUp && !bUp) {
          return (bDt ?? DateTime(0)).compareTo(aDt ?? DateTime(0));
        }
        return aUp ? -1 : 1;
      });

      setState(() {
        _appointments = sorted;
        _loading      = false;
        _hasLoaded    = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<DateTime, List<Map<String, dynamic>>> get _appointmentsByDay {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final appt in _appointments) {
      final iso = appt['start'] as String? ?? '';
      if (iso.isEmpty) continue;
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      (map[day] ??= []).add(appt);
    }
    return map;
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    if (_selectedDay == null) return _appointments;
    final key = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    return _appointmentsByDay[key] ?? [];
  }

  Color _accentColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':    return _brand;
      case 'fulfilled': return _surfHigh;
      case 'cancelled': return _errorRed;
      default:          return _brand;
    }
  }

  Color _chipBg(String status) {
    switch (status.toLowerCase()) {
      case 'booked':    return const Color(0x1A5BA4CF);
      case 'fulfilled': return _surfHigh;
      case 'cancelled': return const Color(0x1AAB1118);
      default:          return const Color(0x1A5BA4CF);
    }
  }

  Color _chipFg(String status) {
    switch (status.toLowerCase()) {
      case 'booked':    return _brand;
      case 'fulfilled': return _onSurfaceV;
      case 'cancelled': return _errorRed;
      default:          return _brand;
    }
  }

  String _chipLabel(String status, String lang) {
    switch (status.toLowerCase()) {
      case 'booked':
      case 'confirmed': return AppStrings.of(lang, 'appointment.confirmed');
      case 'fulfilled': return AppStrings.of(lang, 'appointment.completed');
      case 'cancelled': return AppStrings.of(lang, 'appointment.cancelled');
      default:          return AppStrings.of(lang, 'appointment.confirmed');
    }
  }

  bool _canEnterConsult(Map<String, dynamic> appt) {
    final status = (appt['status'] as String? ?? '').toLowerCase();
    if (status != 'booked') return false;
    final iso = appt['start'] as String? ?? '';
    if (iso.isEmpty) return false;
    final startTime = DateTime.tryParse(iso)?.toLocal();
    if (startTime == null) return false;
    final now = DateTime.now();
    // Allow joining 60 minutes before and up to 120 minutes after scheduled time.
    // Matches the doctor UI join window exactly.
    return startTime.isAfter(now.subtract(const Duration(hours: 1))) &&
           startTime.isBefore(now.add(const Duration(hours: 2)));
  }

  String _formatSlot(TimeOfDay slot) => DateFormatter.formatTime(slot);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context, ref, lang),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _brand))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCalendar(lang),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            AppStrings.of(lang, 'dashboard.appointments_title').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _outline,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        ..._buildAppointmentCards(lang),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          ),
          if (widget.showBookingButton)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _buildCTAButton(lang),
            ),
          // Inline booking panel slides up from bottom
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            height: _showBookingPanel ? 340.0 : 0.0,
            child: _showBookingPanel
                ? SingleChildScrollView(child: _buildBookingPanel(lang))
                : const SizedBox.shrink(),
          ),
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
      leadingWidth: 64,
      leading: Semantics(
        button: true,
        label: AppStrings.of(lang, 'appointment.back_sem'),
        child: InkWell(
          onTap: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.myDoctor);
            }
          },
          child: const SizedBox(
            width: 64,
            height: 64,
            child: Icon(Icons.arrow_back, color: _onSurface, size: 26),
          ),
        ),
      ),
      title: Text(
        widget.screenTitle ?? AppStrings.of(lang, 'appointment.title'),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _onSurface,
        ),
      ),
      centerTitle: true,
    );
  }

  // ── Calendar ──────────────────────────────────────────────────────────────

  Widget _buildCalendar(String lang) {
    final locale = lang == 'ro' ? 'ro_RO' : 'en_US';
    final byDay  = _appointmentsByDay;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: TableCalendar<Map<String, dynamic>>(
        locale: locale,
        firstDay: DateTime.now(),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        // Explicit row heights prevent day cells from being clipped.
        rowHeight: 52.0,
        daysOfWeekHeight: 32.0,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay       = selected;
            _focusedDay        = focused;
            _showBookingPanel  = false;
          });
        },
        onPageChanged: (focused) => _focusedDay = focused,
        eventLoader: (day) {
          final key = DateTime(day.year, day.month, day.day);
          return byDay[key] ?? [];
        },
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _onSurface,
          ),
          // Padding gives sufficient tap area without forcing a 64dp icon
          // that would overflow the default header height and clip day cells.
          leftChevronPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          rightChevronPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leftChevronIcon: Icon(Icons.chevron_left, color: _outline, size: 28),
          rightChevronIcon: Icon(Icons.chevron_right, color: _outline, size: 28),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          selectedDecoration: const BoxDecoration(
            color: _brand,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: _brand.withOpacity(0.30),
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: _brand,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          todayTextStyle: const TextStyle(
            color: _onSurface,
            fontWeight: FontWeight.w600,
          ),
          defaultTextStyle: const TextStyle(color: _onSurface),
          weekendTextStyle: const TextStyle(color: _onSurface),
          markerSize: 6,
          markersMaxCount: 3,
        ),
      ),
    );
  }

  // ── Appointment cards ─────────────────────────────────────────────────────

  List<Widget> _buildAppointmentCards(String lang) {
    final list = _filteredAppointments;
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              AppStrings.of(lang, 'appointment.no_appointments'),
              style: const TextStyle(fontSize: 16, color: _onSurfaceV),
            ),
          ),
        ),
      ];
    }
    return list
        .map((appt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAppointmentCard(appt, lang),
            ))
        .toList();
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt, String lang) {
    final status  = (appt['status'] as String? ?? 'booked').toLowerCase();
    final iso     = appt['start'] as String? ?? '';
    final rawDesc = appt['description'] as String?
        ?? AppStrings.of(lang, 'appointment.video_consult');
    final dateStr = iso.isNotEmpty
        ? DateFormatter.format(iso, includeTime: true)
        : '';

    // Parse "type · specialty · doctorName" format stored by the booking panel.
    // Older entries may just be "Consultație video" — handle gracefully.
    final parts = rawDesc.split(' · ');
    final doctorName = parts.length >= 3
        ? parts.skip(2).join(' · ')       // everything after specialty
        : parts.length == 2 ? parts[1]    // just doctorName without specialty
        : null;
    final specialty = parts.length >= 3 ? parts[1] : null;
    final desc = doctorName ?? rawDesc;    // show doctorName as card title
    final canEnter = _canEnterConsult(appt);

    // FIX 1: Full practitioner name lookup — covers all 9 known practitioners.
    // FIX 2: Safe for-loop search by actor.reference prefix, not by index.
    const practitionerNameMap = {
      Practitioners.familyDoctorId: Practitioners.familyDoctorName,
      'Practitioner/family':        Practitioners.familyDoctorName,
      Practitioners.bogheanuId:     Practitioners.bogheanuName,
      Practitioners.cardioId:       Practitioners.cardioName,
      Practitioners.neuroId:        Practitioners.neuroName,
      Practitioners.dermId:         Practitioners.dermName,
      Practitioners.orthoId:        Practitioners.orthoName,
      Practitioners.ophthaId:       Practitioners.ophthaName,
      Practitioners.psychId:        Practitioners.psychName,
      Practitioners.gyneId:         Practitioners.gyneName,
    };
    final apptParticipants = appt['participant'] as List? ?? [];
    String? practitionerRef;
    for (final p in apptParticipants) {
      final ref = ((p as Map?)?['actor'] as Map?)?['reference'] as String?;
      if (ref != null && ref.startsWith('Practitioner/')) {
        practitionerRef = ref;
        break;
      }
    }
    final resolvedDoctorName = practitionerRef != null
        ? (practitionerNameMap[practitionerRef] ?? practitionerRef)
        : null;

    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar (4dp, tonal — not a 1px border)
            Container(width: 4, color: _accentColor(status)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: _onSurface,
                                ),
                              ),
                              if (specialty != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  specialty,
                                  style: const TextStyle(
                                      fontSize: 13, color: _onSurfaceV),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status chip — pills allowed for chips/tags per DESIGN.md
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _chipBg(status),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _chipLabel(status, lang),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _chipFg(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 14, color: _onSurfaceV),
                      ),
                    ],
                    if (canEnter) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          // FIX 2: disabled (null) when no practitioner participant found.
                          onPressed: resolvedDoctorName != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WaitingRoomScreen(
                                        appointmentId: appt['id'] as String?,
                                        doctorName: resolvedDoctorName,
                                        doctorSpecialty: specialty,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            AppStrings.of(lang, 'appointment.enter_consult'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CTA button ────────────────────────────────────────────────────────────

  Widget _buildCTAButton(String lang) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: () => setState(() {
          _showBookingPanel = !_showBookingPanel;
          _selectedSlot     = null;
        }),
        style: ElevatedButton.styleFrom(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          AppStrings.of(lang, 'appointment.request_new'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Booking panel ─────────────────────────────────────────────────────────

  Widget _buildBookingPanel(String lang) {
    final targetDay = _selectedDay ?? DateTime.now();
    final dayLabel  = DateFormatter.format(
        DateTime(targetDay.year, targetDay.month, targetDay.day).toIso8601String());

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 32,
            spreadRadius: -4,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFBFC7CF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.of(lang, 'appointment.booking_title'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dayLabel,
            style: const TextStyle(fontSize: 16, color: _onSurfaceV),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.of(lang, 'appointment.booking_slot_label'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _outline,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          // Horizontal scrollable time slots.
          // When targetDay is today, only slots strictly after DateTime.now() are shown.
          Builder(builder: (_) {
            final now = DateTime.now();
            final isToday = targetDay.year  == now.year  &&
                            targetDay.month == now.month &&
                            targetDay.day   == now.day;
            final visibleSlots = isToday
                ? _availableSlots
                    .where((slot) => DateTime(
                            targetDay.year, targetDay.month, targetDay.day,
                            slot.hour, slot.minute)
                        .isAfter(now))
                    .toList()
                : List<TimeOfDay>.from(_availableSlots);

            if (visibleSlots.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    AppStrings.of(lang, 'appointment.no_slots_today'),
                    style: const TextStyle(fontSize: 15, color: _onSurfaceV),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visibleSlots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final slot     = visibleSlots[i];
                  final selected = _selectedSlot == slot;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlot = slot),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _brand : _surfLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatSlot(slot),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _onSaveBooking(lang, targetDay),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      disabledBackgroundColor: const Color(0xFFBFC7CF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            AppStrings.of(lang, 'appointment.booking_save'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _showBookingPanel = false;
                      _selectedSlot     = null;
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _brand),
                      foregroundColor: _brand,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      AppStrings.of(lang, 'appointment.booking_cancel'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Save booking ──────────────────────────────────────────────────────────

  Future<void> _onSaveBooking(String lang, DateTime targetDay) async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(lang, 'appointment.select_slot'), style: const TextStyle(fontSize: 16))),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final cnp = ref.read(loginCnpProvider);
      final dateTime = DateTime(
        targetDay.year,
        targetDay.month,
        targetDay.day,
        _selectedSlot!.hour,
        _selectedSlot!.minute,
      );
      final isoString = dateTime.toUtc().toIso8601String();

      // Build description: "Consultație video · {specialty} · {doctorName}"
      // so appointment cards and dashboard can display doctor info (BUG 2 fix).
      final baseType = AppStrings.of(lang, 'appointment.video_consult');
      final specialty = widget.doctorSpecialty;
      final desc = specialty != null
          ? '$baseType · $specialty · ${widget.doctorName}'
          : '$baseType · ${widget.doctorName}';

      await ref.read(fhirRepositoryProvider).saveAppointment(data: {
        'patientId':       cnp,
        'practitionerId':  widget.practitionerRef ?? Practitioners.familyDoctorId,
        'dateTimeIso':     isoString,
        'durationMinutes': 30,
        'description':     desc,
        'status':          'booked',
      });

      if (!mounted) return;
      await _loadAppointments();
      ref.invalidate(appointmentsProvider); // refresh dashboard cache
      setState(() {
        _showBookingPanel = false;
        _selectedSlot     = null;
        _isSaving         = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(lang, 'appointment.booking_success'),
              style: const TextStyle(fontSize: 16)),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(lang, 'appointment.booking_error'),
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
