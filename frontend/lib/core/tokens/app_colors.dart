// lib/core/tokens/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const primary        = Color(0xFF4F46E5);
  static const primaryHover   = Color(0xFF4338CA);
  static const primaryPress   = Color(0xFF3730A3);
  static const primarySoft    = Color(0xFFEEF2FF);
  static const success        = Color(0xFF22C55E);
  static const successSoft    = Color(0xFFDCFCE7);
  static const warning        = Color(0xFFF59E0B);
  static const warningSoft    = Color(0xFFFEF3C7);
  static const error          = Color(0xFFEF4444);
  static const errorSoft      = Color(0xFFFEE2E2);
  static const info           = Color(0xFF3B82F6);
  static const infoSoft       = Color(0xFFDBEAFE);
  static const bgLight        = Color(0xFFF8F9FA);
  static const cardLight      = Color(0xFFFFFFFF);
  static const sunkenLight    = Color(0xFFF1F5F9);
  static const hoverLight     = Color(0x0A0F172A);
  static const borderLight    = Color(0xFFE5E7EB);
  static const borderStrong   = Color(0xFFD1D5DB);
  static const fgLight        = Color(0xFF111827);
  static const fgMutedLight   = Color(0xFF4B5563);
  static const fgSubtleLight  = Color(0xFF6B7280);
  static const fgDisabled     = Color(0xFF9CA3AF);
  static const bgDark         = Color(0xFF0F172A);
  static const cardDark       = Color(0xFF1E293B);
  static const sunkenDark     = Color(0xFF1E293B);
  static const hoverDark      = Color(0x0AF1F5F9);
  static const borderDark     = Color(0xFF1F2937);
  static const fgDark         = Color(0xFFF1F5F9);
  static const fgMutedDark    = Color(0xFFCBD5E1);
  static const fgSubtleDark   = Color(0xFF94A3B8);
  static const fgDisabledDark = Color(0xFF64748B);
  static const shadowBase     = Color(0x0A0F172A);
  static const shadowMd       = Color(0x140F172A);

  static Color bg(Brightness b) => b == Brightness.dark ? bgDark : bgLight;
  static Color card(Brightness b) => b == Brightness.dark ? cardDark : cardLight;
  static Color border(Brightness b) => b == Brightness.dark ? borderDark : borderLight;
  static Color fg(Brightness b) => b == Brightness.dark ? fgDark : fgLight;
  static Color fgMuted(Brightness b) => b == Brightness.dark ? fgMutedDark : fgMutedLight;
  static Color fgSubtle(Brightness b) => b == Brightness.dark ? fgSubtleDark : fgSubtleLight;
  static Color hover(Brightness b) => b == Brightness.dark ? hoverDark : hoverLight;
  static Color disabledMode(Brightness b) => b == Brightness.dark ? fgDisabledDark : fgDisabled;
}