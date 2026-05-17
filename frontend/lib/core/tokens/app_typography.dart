import 'package:flutter/material.dart';

/// DocGen VN — Typography scale
/// UI font: Inter | Code font: JetBrains Mono
class AppTypography {
  AppTypography._();

  static const _ui   = 'Inter';
  static const _mono = 'JetBrainsMono';

  // ── Headings ─────────────────────────────────────────────────────────────
  static const h1 = TextStyle(
    fontFamily: _ui, fontSize: 32, fontWeight: FontWeight.w700,
    letterSpacing: -0.64, height: 1.3,
  );
  static const h2 = TextStyle(
    fontFamily: _ui, fontSize: 24, fontWeight: FontWeight.w600,
    letterSpacing: -0.24, height: 1.3,
  );
  static const h3 = TextStyle(
    fontFamily: _ui, fontSize: 20, fontWeight: FontWeight.w600,
    letterSpacing: -0.2, height: 1.3,
  );
  static const h4 = TextStyle(
    fontFamily: _ui, fontSize: 16, fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // ── Body ─────────────────────────────────────────────────────────────────
  static const body = TextStyle(
    fontFamily: _ui, fontSize: 14, fontWeight: FontWeight.w400, height: 1.5,
  );
  static const bodyMedium = TextStyle(
    fontFamily: _ui, fontSize: 14, fontWeight: FontWeight.w500, height: 1.5,
  );
  static const bodySemibold = TextStyle(
    fontFamily: _ui, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5,
  );
  static const bodySmall = TextStyle(
    fontFamily: _ui, fontSize: 13, fontWeight: FontWeight.w400, height: 1.5,
  );
  static const caption = TextStyle(
    fontFamily: _ui, fontSize: 12, fontWeight: FontWeight.w400, height: 1.4,
  );
  static const label = TextStyle(
    fontFamily: _ui, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4,
    letterSpacing: 0.1,
  );

  // ── Code / Mono ───────────────────────────────────────────────────────────
  static const code = TextStyle(
    fontFamily: _mono, fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.6,
    fontFeatures: [FontFeature.enable('liga'), FontFeature.enable('calt')],
  );
  static const codeSm = TextStyle(
    fontFamily: _mono, fontSize: 12, fontWeight: FontWeight.w400, height: 1.6,
  );
  static const codeMedium = TextStyle(
    fontFamily: _mono, fontSize: 13, fontWeight: FontWeight.w500, height: 1.6,
  );
}

// alias used in profile screen
// (already defined above as bodySemibold)
