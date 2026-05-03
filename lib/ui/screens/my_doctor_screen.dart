// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/practitioner_constants.dart';
import 'doctor_profile_screen.dart';

/// Thin wrapper that renders the family-doctor variant of DoctorProfileScreen
/// as the "Medic" tab. Preserves the MyDoctorScreen class name so existing
/// AppRoute.myDoctor and AppBottomNavBar references remain unchanged.
class MyDoctorScreen extends ConsumerWidget {
  const MyDoctorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DoctorProfileScreen(
      showBackButton: false,
      showSpecialtyPicker: true,
      doctorName: Practitioners.familyDoctorName,
      practitionerRef: Practitioners.familyDoctorId,
    );
  }
}
