import 'package:flutter/material.dart';

/// PrivateLM's palette: the indigo-to-violet of the logo as the accent, on
/// neutrals with a slight violet tint. Dark mode is a deep blue-violet, not
/// pure black. Screens read these through [AppTokens] where they can.
class AppColors {
  AppColors._();

  // ── Brand ──
  /// Accent on light backgrounds.
  static const Color accent = Color(0xFF5B4BE6);

  /// Accent on dark backgrounds (lighter, for contrast).
  static const Color accentDark = Color(0xFF9388FF);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color violet = Color(0xFF8B5CF6);

  /// Primary buttons, the user's chat bubbles, the send button.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Light theme ──
  static const Color bgLight = Color(0xFFFCFBFF);
  static const Color surfaceLight = Color(0xFFF3F1FB);
  static const Color surfacePressedLight = Color(0xFFE9E6F7);
  static const Color sunkenLight = Color(0xFFF6F5FC);
  static const Color textLight = Color(0xFF15131F);
  static const Color mutedLight = Color(0xFF6C6982);
  static const Color faintLight = Color(0xFFABA8BD);
  static const Color outlineLight = Color(0xFFD3CFE4);

  // ── Dark theme ──
  static const Color bgDark = Color(0xFF0F0E17);
  static const Color surfaceDark = Color(0xFF191826);
  static const Color surfacePressedDark = Color(0xFF232135);

  /// Sheets, menus, toasts: one step above [surfaceDark].
  static const Color elevatedDark = Color(0xFF211F31);
  static const Color raisedDark = Color(0xFF2C2A41);
  static const Color sunkenDark = Color(0xFF13121D);
  static const Color textDark = Color(0xFFF3F2FA);
  static const Color mutedDark = Color(0xFF9B98B2);
  static const Color faintDark = Color(0xFF615E78);
  static const Color outlineDark = Color(0xFF3A3852);

  /// Secondary text that has to work on both themes.
  static const Color muted = Color(0xFF8F8CA6);

  // ── Semantic ──
  static const Color success = Color(0xFF22B573);
  static const Color successLight = Color(0xFF1F9D63);
  static const Color successDark = Color(0xFF3DDC97);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFD97706);
  static const Color warningDark = Color(0xFFFFB020);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFDC3545);
  static const Color errorDark = Color(0xFFFF6B6B);
}
