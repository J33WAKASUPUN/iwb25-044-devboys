import 'package:flutter/material.dart';

class AppConstants {
  // Colors
  static const Color primaryColor = Color.fromARGB(255, 162, 235, 37);
  static const Color secondaryColor = Color.fromARGB(255, 22, 95, 213);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color textColor = Color(0xFF1E293B); // Added missing textColor

  // Padding
  static const double smallPadding = 8.0;
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;

  // Border Radius
  static const double borderRadius = 12.0;

  // Button Height
  static const double buttonHeight = 56.0; // Added missing buttonHeight

  // Text Styles
  static const TextStyle headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Color(0xFF1E293B),
  );

  static const TextStyle subHeaderStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF334155),
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Color(0xFF475569),
  );

  // Added missing buttonStyle
  static const TextStyle buttonStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFFFFFFFF),
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Color(0xFF64748B),
  );

  // Added missing status colors
  static const Map<String, Color> statusColors = {
    'TODO': Color(0xFF6B7280),
    'IN_PROGRESS': Color(0xFFF59E0B),
    'COMPLETED': Color(0xFF10B981),
  };

  // Added missing priority colors
  static const Map<String, Color> priorityColors = {
    'LOW': Color(0xFF10B981),
    'MEDIUM': Color(0xFFF59E0B),
    'HIGH': Color(0xFFEF4444),
  };
}

// API Response Status
class ApiStatus {
  static const String success = 'success';
  static const String error = 'error';
  static const String loading = 'loading';
}
