// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

class AppTheme {
  AppTheme._();

  // Thêm 2 hằng số này để đồng bộ hiệu ứng chuyển theme mượt mà trên toàn app
  static const themeTransitionDuration = Duration(milliseconds: 200);
  static const themeCurve = Curves.easeInOut;

  static List<BoxShadow> get shadowSm => const [
    BoxShadow(color: AppColors.shadowBase, blurRadius: 2, offset: Offset(0, 1)),
  ];
  static List<BoxShadow> get shadowMd => const [
    BoxShadow(color: AppColors.shadowMd, blurRadius: 12, offset: Offset(0, 4)),
  ];

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: const ColorScheme.light(
        primary:          AppColors.primary,
        primaryContainer: AppColors.primarySoft,
        surface:          AppColors.cardLight,
        surfaceContainerHighest: AppColors.sunkenLight,
        error:            AppColors.error,
        onPrimary:        Colors.white,
        onSurface:        AppColors.fgLight,
        onSurfaceVariant: AppColors.fgMutedLight,
        outline:          AppColors.borderLight,
        outlineVariant:   AppColors.borderStrong,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rCard,
          side: const BorderSide(color: AppColors.borderLight),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight, thickness: 1, space: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cardLight,
        foregroundColor: AppColors.fgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.h4.copyWith(color: AppColors.fgLight),
        toolbarHeight: 56,
        shape: const Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.cardLight,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.fgMutedLight),
        indicatorColor: AppColors.primarySoft,
        elevation: 0,
      ),
      textTheme: _textTheme(AppColors.fgLight, AppColors.fgMutedLight, AppColors.fgSubtleLight),
      inputDecorationTheme: _inputTheme(Brightness.light),
      elevatedButtonTheme: _elevatedBtn(),
      outlinedButtonTheme: _outlinedBtn(Brightness.light),
      textButtonTheme: _textBtn(),
      iconTheme: const IconThemeData(color: AppColors.fgMutedLight, size: 20),
      chipTheme: _chipTheme(Brightness.light),
      tooltipTheme: _tooltipTheme(Brightness.light),
      popupMenuTheme: _popupTheme(Brightness.light),
      dialogTheme: _dialogTheme(Brightness.light),
      snackBarTheme: _snackbarTheme(),
      checkboxTheme: _checkboxTheme(),
      switchTheme: _switchTheme(),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: const ColorScheme.dark(
        primary:          AppColors.primary,
        primaryContainer: Color(0xFF312E81), // Indigo 900
        surface:          AppColors.cardDark,
        surfaceContainerHighest: AppColors.sunkenDark,
        error:            AppColors.error,
        onPrimary:        Colors.white,
        onSurface:        AppColors.fgDark,
        onSurfaceVariant: AppColors.fgMutedDark,
        outline:          AppColors.borderDark,
        outlineVariant:   Color(0xFF374151),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rCard,
          side: const BorderSide(color: AppColors.borderDark),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark, thickness: 1, space: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cardDark,
        foregroundColor: AppColors.fgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.h4.copyWith(color: AppColors.fgDark),
        toolbarHeight: 56,
        shape: const Border(
          bottom: BorderSide(color: AppColors.borderDark),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.cardDark,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.fgMutedDark),
        indicatorColor: Color(0xFF312E81),
        elevation: 0,
      ),
      textTheme: _textTheme(AppColors.fgDark, AppColors.fgMutedDark, AppColors.fgSubtleDark),
      inputDecorationTheme: _inputTheme(Brightness.dark),
      elevatedButtonTheme: _elevatedBtn(),
      outlinedButtonTheme: _outlinedBtn(Brightness.dark),
      textButtonTheme: _textBtn(),
      iconTheme: const IconThemeData(color: AppColors.fgMutedDark, size: 20),
      chipTheme: _chipTheme(Brightness.dark),
      tooltipTheme: _tooltipTheme(Brightness.dark),
      popupMenuTheme: _popupTheme(Brightness.dark),
      dialogTheme: _dialogTheme(Brightness.dark),
      snackBarTheme: _snackbarTheme(),
      checkboxTheme: _checkboxTheme(),
      switchTheme: _switchTheme(),
    );
  }

  static TextTheme _textTheme(Color fg, Color muted, Color subtle) => TextTheme(
    displayLarge:   AppTypography.h1.copyWith(color: fg),
    displayMedium:  AppTypography.h2.copyWith(color: fg),
    displaySmall:   AppTypography.h3.copyWith(color: fg),
    headlineMedium: AppTypography.h4.copyWith(color: fg),
    bodyLarge:      AppTypography.body.copyWith(color: fg),
    bodyMedium:     AppTypography.bodySmall.copyWith(color: muted),
    bodySmall:      AppTypography.caption.copyWith(color: subtle),
    labelLarge:     AppTypography.bodyMedium.copyWith(color: fg),
    labelMedium:    AppTypography.label.copyWith(color: muted),
    labelSmall:     AppTypography.label.copyWith(color: subtle),
    titleLarge:     AppTypography.h3.copyWith(color: fg),
    titleMedium:    AppTypography.h4.copyWith(color: fg),
    titleSmall:     AppTypography.bodySemibold.copyWith(color: fg),
  );

  static InputDecorationTheme _inputTheme(Brightness b) {
    final isDark = b == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final hint = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;
    return InputDecorationTheme(
      filled: true,
      fillColor: bg,
      hoverColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: AppTypography.body.copyWith(color: hint),
      labelStyle: AppTypography.bodySmall.copyWith(color: hint),
      border: OutlineInputBorder(
        borderRadius: AppRadius.rButton,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.rButton,
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.rButton,
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.rButton,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.rButton,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.rButton,
        borderSide: BorderSide(color: borderColor.withOpacity(0.5)),
      ),
      prefixIconColor: WidgetStateColor.resolveWith((s) =>
      s.contains(WidgetState.focused) ? AppColors.primary : hint),
      suffixIconColor: WidgetStateColor.resolveWith((s) =>
      s.contains(WidgetState.focused) ? AppColors.primary : hint),
    );
  }

  static ElevatedButtonThemeData _elevatedBtn() => ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return AppColors.fgDisabled;
        if (s.contains(WidgetState.pressed))  return AppColors.primaryPress;
        if (s.contains(WidgetState.hovered))  return AppColors.primaryHover;
        return AppColors.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.disabled) ? Colors.white54 : Colors.white),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      elevation: WidgetStateProperty.all(0),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: AppRadius.rButton),
      ),
      textStyle: WidgetStateProperty.all(AppTypography.bodyMedium),
      animationDuration: const Duration(milliseconds: 120),
    ),
  );

  static OutlinedButtonThemeData _outlinedBtn(Brightness b) {
    final isDark = b == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final hover = isDark ? AppColors.hoverDark : AppColors.hoverLight;
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.disabled) ? AppColors.fgDisabled : fg),
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.hovered) ? hover : Colors.transparent),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        side: WidgetStateProperty.resolveWith((s) => BorderSide(
          color: s.contains(WidgetState.focused) ? AppColors.primary : border,
          width: s.contains(WidgetState.focused) ? 2 : 1,
        )),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: AppRadius.rButton),
        ),
        textStyle: WidgetStateProperty.all(AppTypography.bodyMedium),
        animationDuration: const Duration(milliseconds: 120),
      ),
    );
  }

  static TextButtonThemeData _textBtn() => TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.disabled) ? AppColors.fgDisabled : AppColors.primary),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      backgroundColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.hovered) ? AppColors.primarySoft : Colors.transparent),
      elevation: WidgetStateProperty.all(0),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: AppRadius.rButton),
      ),
      textStyle: WidgetStateProperty.all(AppTypography.bodyMedium),
      animationDuration: const Duration(milliseconds: 120),
    ),
  );

  static ChipThemeData _chipTheme(Brightness b) {
    final isDark = b == Brightness.dark;
    return ChipThemeData(
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      selectedColor: AppColors.primarySoft,
      labelStyle: AppTypography.bodySmall.copyWith(
        color: isDark ? AppColors.fgDark : AppColors.fgLight,
      ),
      side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rButton),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  static TooltipThemeData _tooltipTheme(Brightness b) {
    final isDark = b == Brightness.dark;
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardLight : AppColors.fgLight,
        borderRadius: AppRadius.rButton,
        boxShadow: shadowSm,
      ),
      textStyle: AppTypography.caption.copyWith(
        color: isDark ? AppColors.fgLight : AppColors.fgDark,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: const Duration(milliseconds: 600),
    );
  }

  static PopupMenuThemeData _popupTheme(Brightness b) {
    final isDark = b == Brightness.dark;
    return PopupMenuThemeData(
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rCard,
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      textStyle: AppTypography.body.copyWith(
        color: isDark ? AppColors.fgDark : AppColors.fgLight,
      ),
    );
  }

  static DialogThemeData _dialogTheme(Brightness b) {
    final isDark = b == Brightness.dark;
    return DialogThemeData(
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rCard,
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      titleTextStyle: AppTypography.h4.copyWith(
        color: isDark ? AppColors.fgDark : AppColors.fgLight,
      ),
      contentTextStyle: AppTypography.body.copyWith(
        color: isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight,
      ),
    );
  }

  static SnackBarThemeData _snackbarTheme() => const SnackBarThemeData(
    backgroundColor: Color(0xFF1E293B),
    contentTextStyle: TextStyle(
      fontFamily: 'Inter', fontSize: 14, color: AppColors.fgDark,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.rCard),
    elevation: 0,
  );

  static CheckboxThemeData _checkboxTheme() => CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((s) =>
    s.contains(WidgetState.selected) ? AppColors.primary : Colors.transparent),
    checkColor: WidgetStateProperty.all(Colors.white),
    side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
  );

  static SwitchThemeData _switchTheme() => SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((s) =>
    s.contains(WidgetState.selected) ? Colors.white : AppColors.fgDisabled),
    trackColor: WidgetStateProperty.resolveWith((s) =>
    s.contains(WidgetState.selected) ? AppColors.primary : AppColors.borderStrong),
    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
  );
}