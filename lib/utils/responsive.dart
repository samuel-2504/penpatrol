import 'package:flutter/material.dart';

/// Simple breakpoint helpers so screens can adapt their layout
/// (columns, padding, max width) across phones, tablets, and desktop/web.
class Responsive {
  Responsive._();

  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileMax && w < tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  /// Number of grid columns for cards/tiles based on width.
  static int columns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= tabletMax) return 4;
    if (w >= mobileMax) return 3;
    return 2;
  }

  /// Horizontal page padding that grows gently with screen size.
  static double pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= tabletMax) return 48;
    if (w >= mobileMax) return 32;
    return 16;
  }

  /// Clamp content to a comfortable max width on large screens.
  static double contentMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= tabletMax ? 900 : w;
  }
}

/// Wraps a screen body so it is centered and width-capped on large
/// screens, while remaining full-bleed on phones.
class ResponsiveScaffoldBody extends StatelessWidget {
  final Widget child;
  const ResponsiveScaffoldBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final maxWidth = Responsive.contentMaxWidth(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
