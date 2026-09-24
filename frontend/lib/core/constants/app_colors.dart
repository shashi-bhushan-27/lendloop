import 'package:flutter/material.dart';

/// LendLoop Color Palette
///
/// Green (Borrow) + Amber-Orange (Lend): a deliberate two-color brand pair
/// for a two-sided marketplace, chosen to sit clearly outside the blue/violet
/// family. Green reads as trustworthy/sustainable (receiving an item, low
/// cost to the borrower), orange reads as warm/generous (giving one away) —
/// a classic, high-contrast complementary pairing that keeps the Borrow/Lend
/// tabs visually distinct at a glance. Kept clear of the existing semantic
/// colors below (success/warning/error/info), which are left untouched since
/// they carry specific status meaning across the app (transaction states,
/// item status) — success in particular uses a more teal-leaning emerald so
/// it doesn't get lost against the primary green.
class AppColors {
  AppColors._();

  // Primary — Green ("Borrow")
  static const Color primary = Color(0xFF16A34A);       // green-600
  static const Color primaryLight = Color(0xFF22C55E);  // green-500
  static const Color primaryDark = Color(0xFF15803D);   // green-700

  // Accent — Amber-Orange ("Lend")
  static const Color accent = Color(0xFFF97316);        // orange-500
  static const Color accentLight = Color(0xFFFB923C);   // orange-400
  static const Color accentDark = Color(0xFFEA580C);    // orange-600

  /// Semantic aliases used on the home page's Borrow/Lend split — same
  /// values as [primary]/[accent], named for readability at call sites.
  static const Color borrowColor = primary;
  static const Color lendColor = accent;

  // Background
  static const Color background = Color(0xFFF8FAFC);    // slate-50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9); // slate-100

  // Dark Mode
  static const Color darkBackground = Color(0xFF0F172A); // slate-900
  static const Color darkSurface = Color(0xFF1E293B);    // slate-800
  static const Color darkSurfaceVariant = Color(0xFF334155); // slate-700

  // Text
  static const Color textPrimary = Color(0xFF0F172A);    // slate-900
  static const Color textSecondary = Color(0xFF64748B);  // slate-500
  static const Color textTertiary = Color(0xFF94A3B8);   // slate-400
  static const Color textInverse = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF10B981);  // emerald-500
  static const Color warning = Color(0xFFF59E0B);  // amber-500
  static const Color error = Color(0xFFEF4444);    // red-500
  static const Color info = Color(0xFF3B82F6);     // blue-500

  // Trust Score Colors
  static const Color trustHigh = Color(0xFF10B981);    // 75-100
  static const Color trustMedium = Color(0xFFF59E0B);  // 40-75
  static const Color trustLow = Color(0xFFEF4444);     // 0-40

  // Status Colors
  static const Color statusAvailable = Color(0xFF10B981);
  static const Color statusBorrowed = Color(0xFFF59E0B);
  static const Color statusUnavailable = Color(0xFF94A3B8);
  static const Color statusOverdue = Color(0xFFEF4444);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border
  static const Color border = Color(0xFFE2E8F0);      // slate-200
  static const Color borderDark = Color(0xFF334155);  // slate-700

  // Shadow
  static const Color shadow = Color(0x1A000000);

  // Overlay / Barrier
  static const Color overlayBarrier = Color(0x73000000);   // ~45% black
  static const Color overlayBadge = Color(0x8A000000);      // ~54% black

  // On-gradient text/icons (white tones for use on colored backgrounds)
  static const Color onGradient = Color(0xFFFFFFFF);          // pure white
  static const Color onGradientSecondary = Color(0xB3FFFFFF); // white70
}
