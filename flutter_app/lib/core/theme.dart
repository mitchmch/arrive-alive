import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF4361EE);
  static const Color primaryDark = Color(0xFF2946C7);
  static const Color secondary = Color(0xFF7B91F5);
  static const Color caution = Color(0xFFEB6424);
  static const Color alert = Color(0xFFF9C784);
  static const Color danger = Color(0xFFDD2D4A);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = caution;
  static const Color destructive = danger;

  // Blue-tinted light neutrals.
  static const Color background = Color(0xFFF4F7FF);
  static const Color surface = Color(0xFFF9FAFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF17213C);
  static const Color textMuted = Color(0xFF5C6784);
  static const Color border = Color(0xFFD8E0F5);

  // Deep navy dark neutrals.
  static const Color darkBg = Color(0xFF080F24);
  static const Color darkSurface = Color(0xFF101A35);
  static const Color darkCard = Color(0xFF172343);
  static const Color darkBorder = Color(0xFF2A3960);
  static const Color darkText = Color(0xFFF0F4FF);
  static const Color darkTextMuted = Color(0xFFAAB6D5);
  static const Color darkPrimary = Color(0xFF91A6FF);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDDE5FF),
    onPrimaryContainer: const Color(0xFF10266D),
    secondary: primaryDark,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE6EBFF),
    onSecondaryContainer: const Color(0xFF1C2E69),
    error: destructive,
    surface: surface,
    onSurface: textPrimary,
    outline: border,
    outlineVariant: const Color(0xFFE5EAF8),
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
    primary: darkPrimary,
    onPrimary: const Color(0xFF071849),
    primaryContainer: const Color(0xFF233B91),
    onPrimaryContainer: const Color(0xFFDFE6FF),
    secondary: const Color(0xFFB7C5FF),
    onSecondary: const Color(0xFF12245D),
    secondaryContainer: const Color(0xFF26386E),
    onSecondaryContainer: const Color(0xFFE0E6FF),
    error: const Color(0xFFFFB1C0),
    surface: darkSurface,
    onSurface: darkText,
    outline: darkBorder,
    outlineVariant: const Color(0xFF202E50),
  );

  static ThemeData get lightTheme => _buildTheme(
        scheme: _lightScheme,
        scaffold: background,
        cardColor: card,
        mutedText: textMuted,
        borderColor: border,
      );

  static ThemeData get darkTheme => _buildTheme(
        scheme: _darkScheme,
        scaffold: darkBg,
        cardColor: darkCard,
        mutedText: darkTextMuted,
        borderColor: darkBorder,
      );

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffold,
    required Color cardColor,
    required Color mutedText,
    required Color borderColor,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final baseTextTheme = GoogleFonts.dmSansTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );
    final buttonTextStyle = GoogleFonts.dmSans(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      dividerColor: borderColor,
      cardColor: cardColor,
      disabledColor: mutedText.withValues(alpha: 0.45),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: borderColor, width: 0.75),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.dmSans(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        bodyLarge: GoogleFonts.dmSans(fontSize: 16, color: scheme.onSurface),
        bodyMedium: GoogleFonts.dmSans(fontSize: 14, color: scheme.onSurface),
        bodySmall: GoogleFonts.dmSans(fontSize: 12, color: mutedText),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        labelMedium: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: mutedText,
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          elevation: 1,
          shadowColor: scheme.primary.withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        labelStyle: GoogleFonts.dmSans(fontSize: 14, color: mutedText),
        hintStyle: GoogleFonts.dmSans(fontSize: 14, color: mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: mutedText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : mutedText,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : mutedText,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: 14,
          height: 1.45,
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: cardColor,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF223157) : const Color(0xFF17213C),
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
        actionTextColor: isDark ? darkPrimary : const Color(0xFFC9D5FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
