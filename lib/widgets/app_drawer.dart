import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alerts_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/swine_bath_screen.dart';
import '../screens/alerts_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;
    final border = context.extras.border;
    final themeProvider = context.watch<ThemeProvider>();
    final unread = context.watch<AlertsProvider>().unreadCount;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(Icons.shield, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pen Patrol',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        Text(
                          'v1.0.0',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SectionLabel('Main'),
            _DrawerItem(
              icon: Icons.home_rounded,
              label: 'Dashboard',
              onTap: () => _navigate(context, const DashboardScreen()),
            ),
            _DrawerItem(
              icon: Icons.water_drop_rounded,
              label: 'Swine Bath',
              onTap: () => _navigate(context, const SwineBathScreen()),
            ),
            _DrawerItem(
              icon: Icons.history_rounded,
              label: 'History & Logs',
              onTap: () => _navigate(context, const HistoryScreen()),
            ),
            const SizedBox(height: 12),
            _SectionLabel('Controls'),
            _DrawerItem(
              icon: Icons.notifications_rounded,
              label: 'Alerts',
              badgeCount: unread,
              onTap: () => _navigate(context, const AlertsScreen()),
            ),
            const SizedBox(height: 12),
            _SectionLabel('Preferences'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        themeProvider.isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        size: 20,
                        color: muted,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        themeProvider.isDark ? 'Dark Mode' : 'Light Mode',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Switch(
                    value: themeProvider.isDark,
                    onChanged: (v) => themeProvider.setDark(v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.teal,
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: Icons.settings_rounded,
              label: 'App Settings',
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App Settings — coming soon')),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '© 2025 Pen Patrol',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: muted),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }
}
