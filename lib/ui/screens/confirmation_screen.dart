// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.check_circle, size: 100, color: Color(0xFF5BA4CF)),
              SizedBox(height: 48),
              Text(
                'Consultația a fost salvată cu succes.',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Datele au fost înregistrate sigur în dosarul local.',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              // CRITICAL OVERRIDE:
              // 'Înapoi la Ecranul Principal' removed to prevent cognitive overload.
              // Navigation back to home is handled automatically after 5 seconds.
            ],
          ),
        ),
      ),
    );
  }
}
