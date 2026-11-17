import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        bg: AppColors.darkBg,
        surface: AppColors.darkSurface,
        card: AppColors.darkCard,
        muted: AppColors.darkMuted,
        border: AppColors.darkBorder,
        textColor: Colors.white,
      );

  static ThemeData get light => _base(
        brightness: Brightness.light,
        bg: AppColors.lightBg,
        surface: AppColors.lightSurface,
        card: AppColors.lightCard,
        muted: AppColors.lightMuted,
        border: AppColors.lightBorder,
        textColor: const Color(0xFF0F172A),
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color card,
    required Color muted,
    required Color border,
    required Color textColor,
  }) {
    final base = ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: AppColors.brandBlue,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.brandBlue,
        onPrimary: Colors.white,
        secondary: AppColors.yellow,
        onSecondary: Colors.black,
        error: AppColors.red,
        onError: Colors.white,
        surface: surface,
        onSurface: textColor,
      ),
      cardColor: card,
      dividerColor: border,
      useMaterial3: true,
      textTheme: (brightness == Brightness.dark
              ? ThemeData.dark().textTheme
              : ThemeData.light().textTheme)
          .apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.titleBarBlue,
        elevation: 0,
        centerTitle: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brandBlue
              : muted.withValues(alpha: 0.3),
        ),
      ),
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        AppExtras(muted: muted, border: border, card: card, bg: bg),
      ],
    );
  }
}

/// Extra theme tokens not covered by [ThemeData] out of the box.
class AppExtras extends ThemeExtension<AppExtras> {
  final Color muted;
  final Color border;
  final Color card;
  final Color bg;

  const AppExtras({
    required this.muted,
    required this.border,
    required this.card,
    required this.bg,
  });

  @override
  AppExtras copyWith({Color? muted, Color? border, Color? card, Color? bg}) {
    return AppExtras(
      muted: muted ?? this.muted,
      border: border ?? this.border,
      card: card ?? this.card,
      bg: bg ?? this.bg,
    );
  }

  @override
  AppExtras lerp(ThemeExtension<AppExtras>? other, double t) {
    if (other is! AppExtras) return this;
    return AppExtras(
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      card: Color.lerp(card, other.card, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
    );
  }
}

extension AppExtrasContext on BuildContext {
  AppExtras get extras => Theme.of(this).extension<AppExtras>()!;
}
