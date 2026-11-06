import 'package:flutter/material.dart';

class AppTheme {
  // Primary Palette inspired by modern clean neo-morphic / glass UI reference
  static const Color background = Color(0xFFF3F5FA); // Ultra-clean subtle blue-grey backdrop
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  
  // Vibrant Sky / Electric Blue Gradients
  static const Color primary = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color accentCyan = Color(0xFF00B4D8);
  
  // Neutral Text and Labels
  static const Color textMain = Color(0xFF1A2138);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF94A3B8);
  
  // Border and Shadows
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0x33CBD5E1);

  // Status colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusSubmitted = Color(0xFF2563EB);
  static const Color statusGraded = Color(0xFF10B981);
  static const Color statusMissing = Color(0xFFEF4444);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF29B6F6), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF075985)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0xEEFFFFFF), Color(0xDDF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Soft Neo-elevation Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      offset: const Offset(0, 10),
      blurRadius: 24,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      offset: const Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
      offset: const Offset(0, 10),
      blurRadius: 20,
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get subtlePillShadow => [
    BoxShadow(
      color: const Color(0xFF64748B).withValues(alpha: 0.08),
      offset: const Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];
}

