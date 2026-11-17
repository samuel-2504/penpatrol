import 'package:flutter/material.dart';

/// Central color palette for AgroShield IoT - Classic Blue Edition.
class AppColors {
  AppColors._();

  // --- RESTORED DEFAULT PERSPECTIVE COLORS FOR ICONS/STATUSES ---
  static const Color teal = Color(0xFF14B8A6);
  static const Color yellow = Color(0xFFFACC15);
  static const Color orange = Color(0xFFF97316);
  static const Color red = Color(0xFFEF4444);
  static const Color amber = Color(0xFFF59E0B);

  // --- BRAND NEW BLUE INTERFACE ACCENTS ---
  static const Color brandBlue =
      Color(0xFF007AFF); // Striking Electric Blue primary accent
  static const Color titleBarBlue =
      Color(0xFF004E9B); // Deep, rich blue header bar
  static const Color lightBlueText = Color(0xFFBFDBFE); // Soft ice-blue subtext

  // Deep Blue Dark theme surfaces
  static const Color darkBg = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF141C2E);
  static const Color darkCard = Color(0xFF1B2438);
  static const Color darkMuted = Color(0xFF7C8AA5);
  static const Color darkBorder = Color(0xFF2A3550);

  // Crisp Light theme surfaces
  static const Color lightBg = Color(0xFFF3F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightMuted = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return yellow;
      case 'OFFLINE':
        return orange;
      case 'READY':
      default:
        return teal;
    }
  }

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'red':
        return red;
      case 'amber':
        return amber;
      default:
        return teal;
    }
  }
}
