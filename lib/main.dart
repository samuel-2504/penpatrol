import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemChrome
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'providers/theme_provider.dart';
import 'providers/alerts_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/spray_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/history_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hide the top status bar and bottom navigation bar for immersive full screen
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PenPatrolApp());
}

class PenPatrolApp extends StatelessWidget {
  const PenPatrolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => SprayProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'PenPatrol IoT',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.2,
                  ),
                ),
                child: AdaptiveRatioWrapper(
                  child: child!,
                ),
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class AdaptiveRatioWrapper extends StatelessWidget {
  final Widget child;

  const AdaptiveRatioWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Simplified to naturally expand and fill the screen in both portrait and landscape
    return SizedBox.expand(
      child: child,
    );
  }
}