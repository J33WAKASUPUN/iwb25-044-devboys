import 'package:flutter/material.dart';

class AppConstants {
  // Dark Theme Colors
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color secondaryColor = Color(0xFF8B5CF6); // Purple
  static const Color accentColor = Color(0xFF06B6D4); // Cyan
  static const Color backgroundColor = Color(0xFF0F172A); // Dark slate
  static const Color surfaceColor = Color(0xFF1E293B); // Slightly lighter
  static const Color cardColor = Color(0xFF334155); // Card background
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color textColor = Color(0xFFE2E8F0); // Light gray for text
  static const Color textSecondaryColor = Color(0xFF94A3B8); // Muted text
  static const Color borderColor = Color(0xFF475569);
  static const Color inputFillColor = Color(0xFF1E293B);

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
  ];
  
  static const List<Color> backgroundGradient = [
    Color(0xFF0F172A),
    Color(0xFF1E293B),
  ];

  // Padding
  static const double smallPadding = 8.0;
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;

  // Border Radius
  static const double borderRadius = 16.0;
  static const double smallBorderRadius = 12.0;

  // Button Height
  static const double buttonHeight = 56.0;

  // Text Styles
  static const TextStyle headerStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Color(0xFFE2E8F0),
    letterSpacing: -0.5,
  );

  static const TextStyle subHeaderStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFFCBD5E1),
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Color(0xFF94A3B8),
  );

  static const TextStyle buttonStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFFFFFFFF),
    letterSpacing: 0.5,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Color(0xFF64748B),
  );

  // Input Decoration Theme
  static InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: inputFillColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(smallBorderRadius),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(smallBorderRadius),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(smallBorderRadius),
      borderSide: BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(smallBorderRadius),
      borderSide: BorderSide(color: errorColor),
    ),
    labelStyle: TextStyle(color: textSecondaryColor),
    hintStyle: TextStyle(color: textSecondaryColor),
  );

  // Status Colors
  static const Map<String, Color> statusColors = {
    'TODO': Color(0xFF6B7280),
    'IN_PROGRESS': Color(0xFFF59E0B),
    'COMPLETED': Color(0xFF10B981),
  };

  // Priority Colors
  static const Map<String, Color> priorityColors = {
    'LOW': Color(0xFF10B981),
    'MEDIUM': Color(0xFFF59E0B),
    'HIGH': Color(0xFFEF4444),
  };

  // Box Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: primaryColor.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

// API Response Status
class ApiStatus {
  static const String success = 'success';
  static const String error = 'error';
  static const String loading = 'loading';
}
