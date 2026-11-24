import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/alerts_provider.dart';
import '../theme/app_colors.dart';
import '../screens/alerts_screen.dart';

/// Custom app bar used on every non-splash screen.
/// Background is a constant deep blue regardless of theme.
class TitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String? screenName;
  final Widget? leading;
  final bool showNotifications;

  const TitleBar({
    super.key,
    this.screenName,
    this.leading,
    this.showNotifications = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final unreadCount = context.watch<AlertsProvider>().unreadCount;

    return AppBar(
      backgroundColor: AppColors.titleBarBlue,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      leadingWidth: leading == null ? 0 : null,
      leading: leading,
      title: const Text(
        'Pen Patrol',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.lightBlueText,
          letterSpacing: 0.4,
        ),
      ),
      actions: [
        // --- NOTIFICATION BELL ---
        if (showNotifications && screenName?.toLowerCase() != 'alerts') ...[
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AlertsScreen()),
                  );
                },
                icon: const Icon(Icons.notifications_rounded,
                    color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  shape: const CircleBorder(),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        if (screenName?.toLowerCase() != 'hardware & actuators') ...[
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/hardware-actuators'),
            icon: const Icon(
              Icons.settings_input_component_rounded,
              color: Colors.white,
            ),
            tooltip: 'Hardware & Actuators',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // --- THEME TOGGLE ---
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: () => themeProvider.toggle(),
            icon: Icon(
              themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              shape: const CircleBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
