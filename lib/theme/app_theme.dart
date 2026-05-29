import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData get darkTheme {
  final interFamily = GoogleFonts.inter().fontFamily;

  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: false,
    scaffoldBackgroundColor: AppColors.bg0,
    primaryColor: AppColors.accentPurple,
    fontFamily: interFamily,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accentPurple,
      secondary: AppColors.accentBlue,
      surface: AppColors.bg1,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bg1,
      selectedItemColor: AppColors.accentPurple,
      unselectedItemColor: AppColors.textMuted,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg0,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.accentPurple,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accentPurple,
      selectionColor: Color(0x556C5CE7),
      selectionHandleColor: AppColors.accentPurple,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.bg1,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
  );
}

