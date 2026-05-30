import 'package:flutter/material.dart';

/// LendLoop Color Palette
/// A modern, trustworthy color system built around a teal-violet gradient.

class AppColors {
  AppColors._();

  // Primary — Teal
  static const Color primary = Color(0xFF0D9488);       // teal-600
  static const Color primaryLight = Color(0xFF14B8A6);  // teal-500
  static const Color primaryDark = Color(0xFF0F766E);   // teal-700

  // Accent — Violet
  static const Color accent = Color(0xFF7C3AED);        // violet-600
  static const Color accentLight = Color(0xFF8B5CF6);   // violet-500

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
    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border
  static const Color border = Color(0xFFE2E8F0);      // slate-200
  static const Color borderDark = Color(0xFF334155);  // slate-700

  // Shadow
  static const Color shadow = Color(0x1A000000);
}
