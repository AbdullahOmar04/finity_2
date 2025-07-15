import 'package:flutter/material.dart';

final ThemeData blueTheme = ThemeData(
  colorScheme: ColorScheme.light(
    surface: const Color(0xFFE3F2FD), // Light sky blue surface
    primary: const Color(0xFF1976D2), // Primary blue
    secondary: const Color(0xFF42A5F5), // Light blue
    error: Colors.red.shade600,
    onPrimary: Colors.white, // Text on primary
    onSecondary: Colors.white, // Text on secondary
    onError: Colors.white,
    onSurface: const Color(0xFF0D47A1), // Dark blue text
    tertiary: const Color(0xFF87CEEB), // Sky blue accent
    onTertiary: const Color(0xFF0D47A1), // Text on tertiary
  ),
);
