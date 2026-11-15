import 'package:flutter/material.dart';

/// Paleta extraída de `asset/logo.jpg` (nanquim + aquarela):
/// fumaça violeta, paletó sépia, tinta escura e papel creme.
abstract final class BrandColors {
  /// Fumaça violeta: cor de marca / ações principais.
  static const violet = Color(0xFF5B4FC4);
  static const violetLight = Color(0xFF9D95E6);

  /// Paletó sépia: investimentos / destaques quentes.
  static const sepia = Color(0xFF8C6A3F);
  static const sepiaLight = Color(0xFFC9A978);

  /// Ocre do fundo da aquarela.
  static const ochre = Color(0xFFA18C65);

  /// Nanquim: fundo do tema escuro.
  static const ink = Color(0xFF131919);
  static const inkSoft = Color(0xFF2B3433);
  static const slate = Color(0xFF646A71);

  /// Papel: fundo do tema claro.
  static const paper = Color(0xFFF4F2EC);
  static const paperDark = Color(0xFFE9E9F1);
  static const lavenderGray = Color(0xFFBBB8C3);

  /// Semântica financeira.
  static const gain = Color(0xFF3E8E64);
  static const loss = Color(0xFFB2443F);
}

/// Tema global da aplicação. Nenhuma feature deve definir cores próprias;
/// tudo passa por aqui para manter consistência visual.
abstract final class AppTheme {
  static ThemeData get light => _build(
        ColorScheme.fromSeed(
          seedColor: BrandColors.violet,
          brightness: Brightness.light,
        ).copyWith(
          primary: BrandColors.violet,
          onPrimary: Colors.white,
          secondary: BrandColors.sepia,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFEADFCC),
          onSecondaryContainer: const Color(0xFF3F2E16),
          tertiary: BrandColors.ochre,
          surface: BrandColors.paper,
          onSurface: const Color(0xFF1F2424),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFFAF9F5),
          surfaceContainer: const Color(0xFFEFEDE6),
          surfaceContainerHigh: const Color(0xFFE6E4DD),
          surfaceContainerHighest: const Color(0xFFDDDBD4),
          outline: BrandColors.slate,
          outlineVariant: BrandColors.lavenderGray,
          error: BrandColors.loss,
        ),
      );

  static ThemeData get dark => _build(
        ColorScheme.fromSeed(
          seedColor: BrandColors.violet,
          brightness: Brightness.dark,
        ).copyWith(
          primary: BrandColors.violetLight,
          onPrimary: const Color(0xFF1E1657),
          primaryContainer: const Color(0xFF433A9E),
          onPrimaryContainer: const Color(0xFFE4E0FF),
          secondary: BrandColors.sepiaLight,
          onSecondary: const Color(0xFF3F2E16),
          secondaryContainer: const Color(0xFF5A4425),
          onSecondaryContainer: const Color(0xFFF2E2C8),
          tertiary: BrandColors.ochre,
          surface: BrandColors.ink,
          onSurface: BrandColors.paperDark,
          surfaceContainerLowest: const Color(0xFF0D1212),
          surfaceContainerLow: const Color(0xFF181F1F),
          surfaceContainer: const Color(0xFF1F2727),
          surfaceContainerHigh: BrandColors.inkSoft,
          surfaceContainerHighest: const Color(0xFF363F3E),
          outline: const Color(0xFF8A9093),
          outlineVariant: const Color(0xFF454D4D),
          error: const Color(0xFFF2B8B5),
        ),
      );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          base.textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}

/// Atalhos semânticos para a UI financeira.
extension FinanceColors on ColorScheme {
  Color get gain =>
      brightness == Brightness.dark ? const Color(0xFF7FC9A0) : BrandColors.gain;
  Color get loss => error;
  Color get income => primary;
  Color get investment => secondary;
}
