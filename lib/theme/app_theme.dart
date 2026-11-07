import 'package:flutter/material.dart';

/// Centralized design system and theme tokens for EduSync.
/// Harmonized with the official Royal Purple / Electric Orbit brand identity.
class AppTheme {
  // Primary Brand Palette (Official EduSync Royal Violet & Orbit Gold)
  static const Color primary = Color(0xFF5B2D8E);       // Official EduSync Royal Purple
  static const Color primaryDark = Color(0xFF3B1569);   // Deep midnight violet
  static const Color primaryLight = Color(0xFF7E48B8);  // Vibrant lilac-violet
  static const Color primarySubtle = Color(0xFFF3E8FF); // Soft violet tint for chips/cards

  // Accent & Semantic Highlights
  static const Color accentOrbit = Color(0xFFFF7A00);   // Orbit amber/orange from official logo
  static const Color accentAmber = Color(0xFFF59E0B);   // Warm warning/attention
  static const Color accentCyan = Color(0xFF0284C7);    // Tech/info cyan
  static const Color accentEmerald = Color(0xFF10B981); // Positive/success emerald

  // Surface and Background Tones
  static const Color background = Color(0xFFF8FAFC);    // Ultra-clean slate-50 backdrop
  static const Color surface = Color(0xFFFFFFFF);       // Crisp white surface
  static const Color surfaceSoft = Color(0xFFF1F5F9);   // Subtle slate-100 card fill
  static const Color cardBg = Color(0xFFFFFFFF);

  // Typography & Content Hierarchy
  static const Color textMain = Color(0xFF0F172A);      // Slate 900 for high-contrast readability
  static const Color textSecondary = Color(0xFF475569); // Slate 600 for body/subtitles
  static const Color textMuted = Color(0xFF94A3B8);     // Slate 400 for secondary hints/dates
  static const Color textLight = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE2E8F0);   // Slate 200 border
  static const Color borderSubtle = Color(0x205B2D8E);  // Brand-tinted subtle border

  // Status & Evaluation Colors
  static const Color statusPending = Color(0xFFD97706);  // Amber 600
  static const Color statusSubmitted = Color(0xFF4338CA);// Indigo 700
  static const Color statusGraded = Color(0xFF059669);   // Emerald 600
  static const Color statusMissing = Color(0xFFDC2626);  // Red 600

  // Premium Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7E3AF2), Color(0xFF5B2D8E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF5B2D8E), Color(0xFF431B6E), Color(0xFF280B4D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orbitGradient = LinearGradient(
    colors: [Color(0xFFFF8A00), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Modern Multi-layered Ambient Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      offset: const Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -2,
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
      color: primary.withValues(alpha: 0.28),
      offset: const Offset(0, 8),
      blurRadius: 18,
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get subtlePillShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      offset: const Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get heroShadow => [
    BoxShadow(
      color: primaryDark.withValues(alpha: 0.35),
      offset: const Offset(0, 12),
      blurRadius: 26,
      spreadRadius: -4,
    ),
  ];
}
