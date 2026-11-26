import 'package:flutter/material.dart';

class AppColors {
  // Dark Theme Colors (Default)
  static const Color darkBackground = Color(0xFF0B132B);
  static const Color darkSurface = Color(0xFF1C2541);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardHover = Color(0xFF27354E);
  static const Color darkBorder = Color(0xFF334155);

  // Light Theme Colors (Soft, Eye-Friendly, Muted Slate/Zinc)
  static const Color lightBackground = Color(0xFFEEF2F6); // Soft muted canvas, comfortable for eyes
  static const Color lightSurface = Color(0xFFF8FAFC);    // Distinct clean sidebar
  static const Color lightCard = Color(0xFFFFFFFF);       // Cards with clear borders
  static const Color lightCardHover = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFDCE2E9);      // Defined soft borders

  // NetScope Accents
  static const Color primaryCyan = Color(0xFF06B6D4);
  static const Color cyanLight = Color(0xFF22D3EE);
  static const Color primaryTeal = Color(0xFF14B8A6);
  static const Color tealLight = Color(0xFF2DD4BF);
  static const Color skyBlue = Color(0xFF38BDF8);

  // Download & Upload Indicators
  static const Color downloadColor = Color(0xFF06B6D4); // Cyan for Downloads
  static const Color uploadColor = Color(0xFF10B981);   // Emerald / Teal for Uploads
  static const Color totalColor = Color(0xFF8B5CF6);    // Violet for Combined Total

  // Status & Utility Colors
  static const Color statusActive = Color(0xFF10B981);
  static const Color statusInactive = Color(0xFF64748B);
  static const Color systemProcess = Color(0xFFA855F7);
  static const Color alertWarning = Color(0xFFF59E0B);
  static const Color alertDanger = Color(0xFFEF4444);

  // Gradients
  static const LinearGradient downloadGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient uploadGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF2DD4BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradientDark = LinearGradient(
    colors: [Color(0x2238BDF8), Color(0x0506B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
