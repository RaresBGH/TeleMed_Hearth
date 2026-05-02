// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';

// ── Design tokens — must match home_screen.dart ───────────────────────────────
const Color _navActive   = Color(0xFF5BA4CF);
const Color _navInactive = Color(0xFF6B7280);

/// Shared glassmorphism bottom navigation bar used by every tabbed screen.
///
/// Self-contained: watches [appNavigationProvider] internally and navigates
/// via the notifier.  Screens host it as the last child of a [Column] inside
/// [Scaffold.body], mirroring the home-screen layout pattern.
///
/// Labels (canonical, never vary): "Acasă" | "Dosar Medical" | "Medic"
class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = ref.watch(appNavigationProvider);

    void go(AppRoute route) =>
        ref.read(appNavigationProvider.notifier).navigateTo(route);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xD9FFFFFF), // white ~85 %
            border: Border(
              top: BorderSide(color: Color(0xFFE2E2E2), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavTab(
                    icon: Icons.home,
                    label: 'Acasă',
                    active: currentRoute == AppRoute.dashboard,
                    onTap: () => go(AppRoute.dashboard),
                  ),
                  _NavTab(
                    icon: Icons.folder_shared,
                    label: 'Dosar Medical',
                    active: currentRoute == AppRoute.history,
                    onTap: () => go(AppRoute.history),
                  ),
                  _NavTab(
                    icon: Icons.medical_services,
                    label: 'Medic',
                    active: currentRoute == AppRoute.myDoctor,
                    onTap: () => go(AppRoute.myDoctor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private helper — identical to _NavTab in home_screen.dart ────────────────

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _navActive : _navInactive;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: active,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: active
                ? BoxDecoration(
                    color: const Color(0xFFEBF5FF),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
