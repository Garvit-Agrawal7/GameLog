import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color bg0 = Color(0xFF0D1117);
  static const Color bg1 = Color(0xFF1A1F2B);
  static const Color bg2 = Color(0xFF2A3342);

  // Accents
  static const Color accentPurple = Color(0xFF6C5CE7);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF10B981);

  // Text
  static const Color textPrimary = Color(0xFFF5F6F8);
  static const Color textSecondary = Color(0xFF8B95A5);
  static const Color textMuted = Color(0xFF4A5568);

  // Semantic
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Gradient
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

