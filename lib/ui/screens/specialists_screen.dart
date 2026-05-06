// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/practitioner_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/specialty.dart';
import '../../core/providers/language_provider.dart';
import 'doctor_profile_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _bg         = Color(0xFFF7F9FE);
const Color _cardBg     = Color(0xFFFFFFFF);
const Color _surfLow    = Color(0xFFF2F4F8);
const Color _brand      = Color(0xFF5BA4CF);
const Color _onSurface  = Color(0xFF191C1F);
const Color _onSurfaceV = Color(0xFF40484E);
const Color _outline    = Color(0xFF70787F);

class SpecialistsScreen extends ConsumerStatefulWidget {
  const SpecialistsScreen({super.key});

  @override
  ConsumerState<SpecialistsScreen> createState() => _SpecialistsScreenState();
}

class _SpecialistsScreenState extends ConsumerState<SpecialistsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Diacritics strip ──────────────────────────────────────────────────────

  static String _stripDiacritics(String s) {
    return s
        .toLowerCase()
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('Ă', 'a')
        .replaceAll('Â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('Î', 'i')
        .replaceAll('ș', 's')
        .replaceAll('Ș', 's')
        .replaceAll('ț', 't')
        .replaceAll('Ț', 't');
  }

  // ── Doctor name resolution ────────────────────────────────────────────────

  String _doctorNameFor(Specialty s, String lang) {
    switch (s.appStringKey) {
      case 'specialist.cardiologie':  return Practitioners.cardioName;
      case 'specialist.neurologie':   return Practitioners.neuroName;
      case 'specialist.dermatologie': return Practitioners.dermName;
      case 'specialist.ortopedie':    return Practitioners.orthoName;
      case 'specialist.oftalmologie': return Practitioners.ophthaName;
      case 'specialist.pediatrie':    return Practitioners.bogheanuName;
      case 'specialist.psihiatrie':   return Practitioners.psychName;
      case 'specialist.ginecologie':  return Practitioners.gyneName;
      default: return '';
    }
  }

  // ── Filtered list ─────────────────────────────────────────────────────────

  List<Specialty> _filtered(String lang) {
    if (_searchQuery.isEmpty) return Specialty.allSpecialties;
    final q = _stripDiacritics(_searchQuery);
    return Specialty.allSpecialties.where((s) {
      final label = _stripDiacritics(AppStrings.of(lang, s.appStringKey));
      return label.contains(q);
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang     = ref.watch(languageProvider);
    final filtered = _filtered(lang);

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context, lang),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildSearchBar(lang),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      AppStrings.of(lang, 'specialist.no_results'),
                      style: const TextStyle(fontSize: 16, color: _onSurfaceV),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildGrid(context, lang, filtered),
                        const SizedBox(height: 24),
                        _buildFooter(context, lang),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, String lang) {
    return AppBar(
      backgroundColor: _cardBg,
      elevation: 0,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      leadingWidth: 64,
      leading: Semantics(
        button: true,
        label: AppStrings.of(lang, 'specialist.back_sem'),
        child: InkWell(
          onTap: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          child: const SizedBox(
            width: 64,
            height: 64,
            child: Icon(Icons.arrow_back, color: _brand, size: 26),
          ),
        ),
      ),
      title: Text(
        AppStrings.of(lang, 'specialist.title'),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _onSurface,
        ),
      ),
      centerTitle: true,
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(String lang) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        color: _surfLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.search, color: _outline, size: 24),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 18, color: _onSurface),
              decoration: InputDecoration(
                hintText: AppStrings.of(lang, 'specialist.search_hint'),
                hintStyle: const TextStyle(fontSize: 18, color: _outline),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: _outline, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
    );
  }

  // ── Specialty grid ────────────────────────────────────────────────────────

  Widget _buildGrid(
      BuildContext context, String lang, List<Specialty> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildSpecialtyCard(context, lang, items[i]),
    );
  }

  Widget _buildSpecialtyCard(
      BuildContext context, String lang, Specialty s) {
    final label = AppStrings.of(lang, s.appStringKey);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorProfileScreen(
                showBackButton:      true,
                showSpecialtyPicker: false,
                doctorName:          _doctorNameFor(s, lang),
                doctorSpecialty:     label,
                practitionerRef:     s.practitionerRef,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                spreadRadius: -2,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(s.icon, color: _brand, size: 32),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context, String lang) {
    return Column(
      children: [
        Text(
          AppStrings.of(lang, 'specialist.footer_question'),
          style: const TextStyle(fontSize: 16, color: _onSurfaceV),
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () {
            // TODO(medplum): route to family doctor messaging thread instead.
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(
            foregroundColor: _brand,
            minimumSize: const Size(0, 56),
          ),
          child: Text(
            AppStrings.of(lang, 'specialist.footer_action'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _brand,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
