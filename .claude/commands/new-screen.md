# New Screen Command
When creating a new screen, always:
1. Read the Stitch design files from /home/corb_d/sovereign-factory/mobile-workspace/stitch_telemed_k/[screen_name]/screen.png and code.html
2. Read lib/ui/theme/theme.dart for colors and typography
3. Read lib/ui/widgets/app_bottom_nav_bar.dart if the screen needs bottom nav
4. Use AppStrings for ALL user-facing strings — never hardcode Romanian or English
5. Add the route to AppRoute enum in lib/core/providers/app_navigation_provider.dart
6. Add the case to the router switch in lib/main.dart
7. Run flutter analyze before finishing
FINISH MESSAGE format: "SCREEN_BUILT — file: [path] — route added: yes/no — strings localized: yes/no — bottom nav: yes/no — analyze errors: N"
