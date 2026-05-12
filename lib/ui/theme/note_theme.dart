import 'package:flutter/material.dart';

class NoteTheme {
  // Notes-inspired colors (light, warm)
  static const Color noteBackground = Color(0xFFFFFDE7); // Warm cream/yellow
  static const Color notePaper = Color(0xFFFFFFFF);
  static const Color headerBackground = Color(0xFFF5F5F5);
  static const Color headerIconColor = Color(0xFFFFCC00); // iOS yellow
  static const Color noteText = Color(0xFF1C1C1E);
  static const Color noteTextSecondary = Color(0xFF636366);
  static const Color noteBorder = Color(0xFFE0E0E0);

  // Text styles for note display
  static TextStyle get noteTitle => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: noteText,
        height: 1.3,
      );

  static TextStyle get noteBody => const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: noteText,
        height: 1.6,
        letterSpacing: 0.2,
      );

  static TextStyle get noteTimestamp => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.grey[600],
      );

  static TextStyle get noteTimestampSmall => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Colors.grey[500],
      );

  // Note container decoration
  static BoxDecoration get noteDecoration => BoxDecoration(
        color: notePaper,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // Header decoration
  static BoxDecoration get headerDecoration => BoxDecoration(
        color: headerBackground,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      );

  // Action bar decoration
  static BoxDecoration get actionBarDecoration => BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      );

  // Format date for display
  static String formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Format time for display
  static String formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

}
