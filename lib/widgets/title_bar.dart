import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/alerts_provider.dart';
import '../theme/app_colors.dart';
import '../screens/alerts_screen.dart';

/// Custom app bar used on every non-splash screen.
/// Background is a constant deep blue regardless of theme.
class TitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String screenName;
  final Widget? leading;

  const TitleBar({super.key, required this.screenName, this.leading});

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
      titleSpacing: 12,
      leadingWidth: leading == null ? 0 : null,
      leading: leading,
      title: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightBlueText,
                ),
                children: [
                  const TextSpan(text: 'Pen Patrol '),
                  TextSpan(
                    text: screenName,
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        // --- NOTIFICATION BELL ---
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                );
              },
              icon:
                  const Icon(Icons.notifications_rounded, color: Colors.white),
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
