import 'package:flutter/material.dart';

class AppThemes {
  // Netflix-style color palette
  static const Color netflixBlack = Color(0xFF000000);
  static const Color surfaceGrey = Color(0xFF141414);
  static const Color surfaceGreyLight = Color(0xFF1F1F1F);
  static const Color surfaceGreyMedium = Color(0xFF2A2A2A);
  static const Color categoryGrey = Color(0xFF999999);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFB3B3B3);
  static const Color iconGrey = Color(0xFF808080);
  static const Color accentRed = Color(0xFFE50914);
  static const Color dividerGrey = Color(0xFF333333);

  // Light theme - keep for compatibility but enhance
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentRed,
      brightness: Brightness.light,
    ),
  );

  // Netflix-style dark theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: netflixBlack,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: accentRed,
      onPrimary: textWhite,
      primaryContainer: surfaceGreyLight,
      onPrimaryContainer: textWhite,
      secondary: surfaceGreyMedium,
      onSecondary: textWhite,
      secondaryContainer: surfaceGreyLight,
      onSecondaryContainer: textWhite,
      tertiary: categoryGrey,
      onTertiary: textWhite,
      tertiaryContainer: surfaceGreyMedium,
      onTertiaryContainer: textWhite,
      error: Color(0xFFCF6679),
      onError: netflixBlack,
      surface: netflixBlack,
      onSurface: textWhite,
      surfaceContainerHighest: surfaceGrey,
      surfaceContainerHigh: surfaceGreyLight,
      surfaceContainer: surfaceGreyMedium,
      outline: dividerGrey,
      outlineVariant: Color(0xFF444444),
    ),
    cardTheme: CardThemeData(
      color: surfaceGrey,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textWhite,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: textWhite),
      actionsIconTheme: IconThemeData(color: textWhite),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: netflixBlack,
      selectedItemColor: textWhite,
      unselectedItemColor: iconGrey,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: netflixBlack,
      indicatorColor: Colors.white.withOpacity(0.1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: textWhite, fontSize: 12, fontWeight: FontWeight.w500);
        }
        return const TextStyle(color: iconGrey, fontSize: 12, fontWeight: FontWeight.w400);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: textWhite, size: 24);
        }
        return const IconThemeData(color: iconGrey, size: 24);
      }),
    ),
    iconTheme: const IconThemeData(color: textWhite, size: 24),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: textWhite, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: textWhite, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textWhite, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textWhite, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: textWhite, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textWhite),
      bodyMedium: TextStyle(color: textGrey),
      bodySmall: TextStyle(color: textGrey),
      labelLarge: TextStyle(color: textWhite, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: textGrey),
      labelSmall: TextStyle(color: textGrey),
    ),
    dividerTheme: const DividerThemeData(
      color: dividerGrey,
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: textWhite,
      iconColor: textWhite,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceGreyLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: const TextStyle(color: textWhite, fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle: const TextStyle(color: textGrey, fontSize: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surfaceGrey,
      modalBackgroundColor: surfaceGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceGreyLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: textWhite),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceGreyMedium,
      selectedColor: accentRed,
      labelStyle: const TextStyle(color: textWhite),
      secondaryLabelStyle: const TextStyle(color: textWhite),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceGreyMedium,
      hintStyle: const TextStyle(color: iconGrey),
      labelStyle: const TextStyle(color: textGrey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentRed, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentRed,
        foregroundColor: textWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textWhite,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentRed,
      foregroundColor: textWhite,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceGreyLight,
      contentTextStyle: const TextStyle(color: textWhite),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: textWhite,
      unselectedLabelColor: iconGrey,
      indicatorColor: accentRed,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: accentRed,
      linearTrackColor: surfaceGreyMedium,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accentRed,
      inactiveTrackColor: surfaceGreyMedium,
      thumbColor: textWhite,
      overlayColor: accentRed.withOpacity(0.2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return textWhite;
        return iconGrey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accentRed;
        return surfaceGreyMedium;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accentRed;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(textWhite),
      side: const BorderSide(color: iconGrey, width: 2),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accentRed;
        return iconGrey;
      }),
    ),
  );
}
