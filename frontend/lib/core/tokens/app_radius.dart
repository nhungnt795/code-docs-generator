import 'package:flutter/material.dart';

/// DocGen VN — Border Radius tokens
class AppRadius {
  AppRadius._();
  static const double badge  = 4;
  static const double button = 6;
  static const double card   = 8;

  static const rBadge  = BorderRadius.all(Radius.circular(badge));
  static const rButton = BorderRadius.all(Radius.circular(button));
  static const rCard   = BorderRadius.all(Radius.circular(card));
  static const rAvatar = BorderRadius.all(Radius.circular(9999));
}
