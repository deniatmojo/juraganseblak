import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna & tipograffi — identik dengan Tailwind config website
/// (web/tailwind.config.js).
class AppColors {
  static const chili = Color(0xFFC81E1E);
  static const chiliDark = Color(0xFF9A1515);
  static const chiliLight = Color(0xFFE63A3A);
  static const ember = Color(0xFFF97316);
  static const emberLight = Color(0xFFFDBA74);
  static const char = Color(0xFF16110F);
  static const charSoft = Color(0xFF231A17);
  static const charLine = Color(0xFF3A2C27);
  static const cream = Color(0xFFFAF3EC);
  static const greenOk = Color(0xFF15803D);
  static const greenBg = Color(0xFFDCFCE7);
  static const redBg = Color(0xFFFEE2E2);
}

/// Font display (judul) = Anton, body = Plus Jakarta Sans — sama seperti web.
class AppText {
  static TextStyle display({double size = 24, Color color = AppColors.char}) =>
      GoogleFonts.anton(
        fontSize: size,
        color: color,
        letterSpacing: 1.2,
        height: 1.1,
      );

  static TextStyle displayDark(double size) => display(size: size);

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.char,
  }) =>
      GoogleFonts.plusJakartaSans(
          fontSize: size, fontWeight: weight, color: color);
}

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.chili,
      secondary: AppColors.ember,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.chili, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.chili),
    ),
  );
}

String formatRp(num n) =>
    'Rp ${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
