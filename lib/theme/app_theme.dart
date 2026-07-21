import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  APP COLORS — Curated Premium Palette
// ═══════════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // Primary
  static const primary = Color(0xFFF52670);
  static const primaryLight = Color(0xFFFF4D8D);
  static const primaryDark = Color(0xFFD41E60);

  // Surfaces
  static const surfaceLight = Color(0xFFF6F3F5);
  static const surfaceDark = Color(0xFF080808);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF141414);
  static const cardDarkElevated = Color(0xFF1C1C1C);

  // Accents
  static const income = Color(0xFF34C759);
  static const expense = Color(0xFFFF9500);
  static const balance = Color(0xFF007AFF);
  static const islamic = Color(0xFF30D5C8);
  static const warning = Color(0xFFFF3B30);

  // Gradients
  static const heroGradientLight = [Color(0xFFFFF0F4), Color(0xFFFCE4EC), Color(0xFFF8F5F7)];
  static const heroGradientDark = [Color(0xFF1A0A10), Color(0xFF140810), Color(0xFF0A0A0A)];
  static const primaryGradient = [Color(0xFFF52670), Color(0xFFFF6B9D)];
  static const incomeGradient = [Color(0xFF34C759), Color(0xFF30D5C8)];
  static const expenseGradient = [Color(0xFFFF9500), Color(0xFFFF6B6B)];
  static const islamicGradient = [Color(0xFF30D5C8), Color(0xFF007AFF)];
}

// ═══════════════════════════════════════════════════════════════════════════
//  APP SHADOWS — Soft Neumorphism Presets
// ═══════════════════════════════════════════════════════════════════════════
class AppShadows {
  AppShadows._();

  static List<BoxShadow> softCard(bool isDark) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.4)
          : Colors.black.withValues(alpha: 0.04),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: isDark
          ? Colors.white.withValues(alpha: 0.02)
          : Colors.white.withValues(alpha: 0.8),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];

  static List<BoxShadow> glowCard(Color color, {bool isDark = false}) => [
    BoxShadow(
      color: color.withValues(alpha: isDark ? 0.2 : 0.15),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> floatingNav(bool isDark) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.5)
          : Colors.black.withValues(alpha: 0.08),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> subtle(bool isDark) => [
    BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
//  APP DECORATION — Reusable BoxDecoration Builders
// ═══════════════════════════════════════════════════════════════════════════
class AppDecoration {
  AppDecoration._();

  /// Standard Bento card — neumorphic soft card
  static BoxDecoration bentoCard(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.cardDark : AppColors.cardLight,
    borderRadius: BorderRadius.circular(24),
    boxShadow: AppShadows.softCard(isDark),
  );

  /// Glassmorphism card
  static BoxDecoration glassCard(bool isDark) => BoxDecoration(
    color: isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.7),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.5),
    ),
  );

  /// Gradient card
  static BoxDecoration gradientCard(List<Color> colors, {bool isDark = false}) => BoxDecoration(
    gradient: LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(24),
    boxShadow: AppShadows.glowCard(colors.first, isDark: isDark),
  );

  /// Floating navigation bar
  static BoxDecoration floatingNav(bool isDark) => BoxDecoration(
    color: isDark
        ? const Color(0xFF1A1A1A).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(28),
    boxShadow: AppShadows.floatingNav(isDark),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  APP TEXT STYLES — Premium Typography (Inter)
// ═══════════════════════════════════════════════════════════════════════════
class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading(bool isDark) => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: isDark ? Colors.white : const Color(0xFF1A0A10),
    letterSpacing: -0.5,
  );

  static TextStyle subheading(bool isDark) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: isDark ? Colors.white : const Color(0xFF1A0A10),
    letterSpacing: -0.3,
  );

  static TextStyle body(bool isDark) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: isDark ? Colors.white70 : const Color(0xFF3A2A30),
    height: 1.4,
  );

  static TextStyle caption(bool isDark) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: isDark ? Colors.white38 : Colors.grey.shade500,
    letterSpacing: 0.2,
  );

  static TextStyle label(bool isDark) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: isDark ? Colors.white60 : Colors.grey.shade600,
    letterSpacing: 0.1,
  );

  static TextStyle metric(bool isDark) => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: isDark ? Colors.white : const Color(0xFF1A0A10),
    letterSpacing: -0.5,
  );

  static TextStyle metricSmall(bool isDark) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: isDark ? Colors.white : const Color(0xFF1A0A10),
    letterSpacing: -0.3,
  );

  static TextStyle navLabel() => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  APP THEME — Premium ThemeData Builder
// ═══════════════════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        surface: AppColors.surfaceLight,
      ),
      textTheme: base,
      scaffoldBackgroundColor: AppColors.surfaceLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A0A10),
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A0A10)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: AppColors.cardLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0ECEE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 0.5,
      ),
    );
  }

  static ThemeData dark() {
    final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        surface: AppColors.surfaceDark,
      ),
      textTheme: base,
      scaffoldBackgroundColor: AppColors.surfaceDark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: AppColors.cardDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1C1C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 0.5,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  BENTO CARD — Reusable Premium Card Widget
// ═══════════════════════════════════════════════════════════════════════════
class BentoCard extends StatelessWidget {
  final Widget child;
  final List<Color>? gradient;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double? width;

  const BentoCard({
    super.key,
    required this.child,
    this.gradient,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final decoration = gradient != null
        ? AppDecoration.gradientCard(gradient!, isDark: isDark)
        : AppDecoration.bentoCard(isDark);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        width: width,
        padding: padding,
        decoration: decoration,
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GLASS CARD — Frosted Glass Widget
// ═══════════════════════════════════════════════════════════════════════════
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: AppDecoration.glassCard(isDark),
          child: child,
        ),
      ),
    );
  }
}
