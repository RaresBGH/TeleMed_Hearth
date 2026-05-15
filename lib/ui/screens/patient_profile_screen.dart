// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers/ai_ready_provider.dart';
import '../../core/providers/app_navigation_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/providers/patient_history_provider.dart';
import '../../core/services/ai_engine_service.dart';
import '../../core/constants/practitioner_constants.dart';
import '../../core/utils/date_formatter.dart';


// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _bg         = Color(0xFFF5F7FA);
const Color _cardBg     = Color(0xFFFFFFFF);
const Color _brand      = Color(0xFF5BA4CF);
const Color _onSurface  = Color(0xFF191C1F);
const Color _outline    = Color(0xFF70787F);
const Color _surfaceLow = Color(0xFFF2F4F8);
const Color _errorRed   = Color(0xFFAB1118);

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _patientData;
  bool _isLoadingData = true;
  bool _hasLoaded     = false;
  bool _isSaving      = false;
  Uint8List?    _avatarBytes;
  String? _originalPhone;
  String? _originalEmail;

  // Derived read-only fields from FHIR data
  String _firstName  = '';
  String _lastName   = '';
  String _dob        = '';
  String _cnpDisplay = '';

  String get _lang => ref.read(languageProvider);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _cnpDisplay = ref.read(loginCnpProvider);
    _loadPatientData();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadPatientData() async {
    if (_hasLoaded) return;
    final cnp = ref.read(loginCnpProvider);
    try {
      final data = await ref.read(fhirRepositoryProvider).getPatientByCnp(cnp);
      if (!mounted) return;
      setState(() {
        _patientData    = data;
        _isLoadingData  = false;
        _hasLoaded      = true;
        if (data != null) _initFromFhir(data);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(_lang, 'error.load_profile'))),
      );
    }
  }

  void _initFromFhir(Map<String, dynamic> data) {
    // Name
    final nameList = data['name'] as List?;
    if (nameList != null && nameList.isNotEmpty) {
      final nameMap = nameList.first as Map<String, dynamic>?;
      final givenList = nameMap?['given'] as List?;
      _firstName = (givenList?.isNotEmpty == true ? givenList!.first : '') as String;
      _lastName  = (nameMap?['family'] ?? '') as String;
    }

    // DOB
    final rawDob = data['birthDate'] as String? ?? '';
    _dob = rawDob.isNotEmpty ? DateFormatter.format(rawDob) : '';

    // Telecom
    final telecoms = data['telecom'] as List? ?? [];
    final phone = telecoms.firstWhere(
      (t) => (t as Map)['system'] == 'phone',
      orElse: () => null,
    );
    _phoneCtrl.text = (phone as Map?)?['value'] as String? ?? '';
    _originalPhone  = _phoneCtrl.text;

    final email = telecoms.firstWhere(
      (t) => (t as Map)['system'] == 'email',
      orElse: () => null,
    );
    _emailCtrl.text = (email as Map?)?['value'] as String? ?? '';
    _originalEmail  = _emailCtrl.text;

    // Photo
    final photos = data['photo'] as List?;
    if (photos != null && photos.isNotEmpty) {
      final photoData = (photos.first as Map)['data'] as String?;
      if (photoData != null) {
        try {
          _avatarBytes = base64Decode(photoData);
          ref.read(patientAvatarProvider.notifier).set(_avatarBytes);
        } catch (_) {}
      }
    }
  }

  // ── Change detection ──────────────────────────────────────────────────────
  bool _hasUnsavedChanges() {
    if (_originalPhone == null || _originalEmail == null) return false;
    return _phoneCtrl.text.trim() != _originalPhone ||
           _emailCtrl.text.trim() != _originalEmail;
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);

  // ── Navigation ────────────────────────────────────────────────────────────
  Future<void> _onBack() async {
    if (!_hasUnsavedChanges()) {
      ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.dashboard);
      return;
    }
    final lang = _lang;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(lang, 'profil.unsaved_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text(AppStrings.of(lang, 'profil.unsaved_body'),
            style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.of(lang, 'profil.unsaved_keep'),
                style: const TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.of(lang, 'profil.unsaved_discard'),
                style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.dashboard);
    }
  }

  // ── Photo picker ──────────────────────────────────────────────────────────
  Future<void> _onPickPhoto() async {
    // Show source dialog
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(AppStrings.of(_lang, 'profile.photo_source'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
            child: Text(AppStrings.of(_lang, 'profile.photo_gallery'), style: const TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
            child: Text(AppStrings.of(_lang, 'profile.photo_camera'), style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final bytes      = await picked.readAsBytes();
      final base64Data = base64Encode(bytes);

      if (_patientData != null) {
        final updated = Map<String, dynamic>.from(_patientData!);
        updated['photo'] = [
          {'contentType': 'image/jpeg', 'data': base64Data}
        ];
        await ref.read(fhirRepositoryProvider).updatePatient(updated);
        _patientData = updated;
      }
      if (!mounted) return;
      setState(() => _avatarBytes = bytes);
      ref.read(patientAvatarProvider.notifier).set(bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(_lang, 'profil.photo_picker_error'),
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _onSave() async {
    if (_isSaving) return;
    final lang         = _lang;
    final phoneChanged = _phoneCtrl.text.trim() != (_originalPhone ?? '');
    final emailChanged = _emailCtrl.text.trim() != (_originalEmail ?? '');

    if (!phoneChanged && !emailChanged) return; // no-op

    if (phoneChanged) {
      // Phone changes are blocked — show informational dialog
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.of(lang, 'profil.phone_change_blocked'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Text(
            AppStrings.of(lang, 'profil.phone_change_body'),
            // TODO(B0): wire device-transfer flow here
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
              child: Text(AppStrings.of(_lang, 'action.ok'), style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
      return; // atomic: do not save email either when phone was also edited
    }

    // Only email changed — validate
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(lang, 'profil.save_error'),
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _saveEmail(email);
      if (!mounted) return;
      _originalEmail = email;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(_lang, 'profil.save_success'),
            style: const TextStyle(fontSize: 16, color: Colors.white)),
        backgroundColor: _brand,
        duration: const Duration(seconds: 2),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(_lang, 'profil.save_error'),
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveEmail(String email) async {
    if (_patientData == null) return;
    final updated  = Map<String, dynamic>.from(_patientData!);
    final telecoms = List<dynamic>.from(updated['telecom'] as List? ?? []);
    final idx      = telecoms.indexWhere((t) => (t as Map)['system'] == 'email');
    final entry    = {'system': 'email', 'value': email, 'use': 'home'};
    if (idx >= 0) {
      telecoms[idx] = entry;
    } else {
      telecoms.add(entry);
    }
    updated['telecom'] = telecoms;
    await ref.read(fhirRepositoryProvider).updatePatient(updated);
    _patientData = updated;
  }

  // ── Delete account ────────────────────────────────────────────────────────
  Future<void> _onDeleteAccount() async {
    final lang     = _lang;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(lang, 'profil.delete_confirm_title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(AppStrings.of(lang, 'profil.delete_confirm_body'),
            style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.of(lang, 'profil.delete_confirm_no'),
                style: const TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: _errorRed),
            child: Text(AppStrings.of(lang, 'profil.delete_confirm_yes'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final cnp = ref.read(loginCnpProvider);

      // (i) Delete FHIR records — must run before auth clear
      await ref.read(fhirRepositoryProvider).deleteAllForPatient(cnp);

      // (ii) Delete model file — before auth clear
      await AiEngineService.deleteModelFile();

      if (!mounted) return;

      // (iii) Reset auth + CNP providers
      ref.read(patientAuthProvider.notifier).reset();
      ref.invalidate(aiReadyProvider);
      ref.invalidate(patientHistoryProvider);

      // (iv) Reset medical session
      await ref.read(medicalSessionProvider.notifier).reset();

      // (v) Navigate to login
      ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.loginIdentity);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.of(_lang, 'profil.save_error'),
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang    = ref.watch(languageProvider);
    final history = ref.watch(patientHistoryProvider);

    // Primary condition from FHIR (same pattern as dashboard)
    final conditionName = history.maybeWhen(
      data: (data) {
        final cond = data.where((e) => e['resourceType'] == 'Condition').toList();
        if (cond.isEmpty) return '';
        final code = cond.first['code'] as Map<String, dynamic>?;
        return code?['text'] as String? ?? '';
      },
      orElse: () => '',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(lang),
        body: _isSaving && _patientData == null
            ? const Center(child: CircularProgressIndicator(color: _brand))
            : _isLoadingData
                ? const Center(child: CircularProgressIndicator(color: _brand))
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAvatar(),
                          const SizedBox(height: 24),
                          _buildEditFormCard(lang),
                          const SizedBox(height: 16),
                          _buildMedicalInfoCard(lang, conditionName),
                          const SizedBox(height: 16),
                          _buildDangerZone(lang),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(String lang) {
    return AppBar(
      backgroundColor: _cardBg,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      leadingWidth: 64,
      leading: Semantics(
        label: AppStrings.of(lang, 'profil.back_sem'),
        button: true,
        child: InkWell(
          onTap: _onBack,
          child: const SizedBox(
            width: 64,
            height: 64,
            child: Icon(Icons.arrow_back, color: _brand, size: 26),
          ),
        ),
      ),
      title: Text(
        AppStrings.of(lang, 'profil.appbar_title'),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _onSurface,
        ),
      ),
      centerTitle: true,
      actions: [
        SizedBox(
          width: 80,
          height: 64,
          child: TextButton(
            onPressed: _isSaving ? null : _onSave,
            child: Text(
              AppStrings.of(lang, 'profil.save_btn'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isSaving ? Colors.grey : _brand,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Avatar section ────────────────────────────────────────────────────────
  Widget _buildAvatar() {
    final displayName =
        _firstName.isNotEmpty || _lastName.isNotEmpty
            ? '$_firstName $_lastName'.trim()
            : (ref.read(patientAuthProvider).patientFirstName ?? '');

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE6E8ED),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _avatarBytes != null
                  ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                  : const Icon(Icons.person, size: 56, color: Color(0xFF8A8E95)),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Semantics(
                label: AppStrings.of(_lang, 'profil.change_photo_sem'),
                button: true,
                child: GestureDetector(
                  onTap: _onPickPhoto,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.photo_camera, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (displayName.isNotEmpty)
          Text(
            displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _onSurface),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 4),
        Text(
          '${AppStrings.of(_lang, 'profile.cnp_prefix')}$_cnpDisplay',
          style: const TextStyle(fontSize: 14, color: _outline, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Edit form card ────────────────────────────────────────────────────────
  Widget _buildEditFormCard(String lang) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReadOnlyField(AppStrings.of(lang, 'profil.first_name_label'), _firstName),
          const SizedBox(height: 20),
          _buildReadOnlyField(AppStrings.of(lang, 'profil.last_name_label'), _lastName),
          const SizedBox(height: 20),
          _buildEditableField(
            AppStrings.of(lang, 'profil.phone_label'),
            _phoneCtrl,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          _buildReadOnlyField(AppStrings.of(lang, 'profil.dob_label'), _dob),
          const SizedBox(height: 20),
          _buildEditableField(
            AppStrings.of(lang, 'profil.email_label'),
            _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            hint: AppStrings.of(lang, 'profil.email_hint'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: _outline, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          decoration: const BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Text(value.isNotEmpty ? value : '—',
              style: const TextStyle(fontSize: 18, color: _outline)),
        ),
      ],
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: _outline, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 18, color: _onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 18, color: Color(0xFFBFC7CF)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFBFC7CF)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _brand, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // ── Medical info card ─────────────────────────────────────────────────────
  Widget _buildMedicalInfoCard(String lang, String conditionName) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.of(lang, 'profil.medical_section'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _outline,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            AppStrings.of(lang, 'profil.condition_label'),
            conditionName.isNotEmpty ? conditionName : '—',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            AppStrings.of(lang, 'profil.family_doctor_label'),
            Practitioners.familyDoctorName,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.of(lang, 'profil.medical_helper'),
            style: const TextStyle(
              fontSize: 14,
              color: _outline,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: _outline, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 18, color: _onSurface, fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  // ── Danger zone ───────────────────────────────────────────────────────────
  Widget _buildDangerZone(String lang) {
    return Semantics(
      button: true,
      label: AppStrings.of(lang, 'profil.delete_account_title'),
      child: InkWell(
        onTap: _isSaving ? null : _onDeleteAccount,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: _errorRed, width: 4),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.of(lang, 'profil.delete_account_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _errorRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.of(lang, 'profil.delete_account_subtitle'),
                      style: const TextStyle(fontSize: 14, color: _outline),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _brand, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
