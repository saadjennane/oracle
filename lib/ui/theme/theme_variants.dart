import 'package:flutter/material.dart';

/// Standalone palette + typography descriptors for the candidate themes.
/// These are NOT wired into AppTheme yet — they exist to power the visual
/// preview screen so the variant can be chosen before the real refactor.
class ThemeVariant {
  final String id;
  final String name;
  final String description;
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accent2;
  final Color ctaText;
  final String displayFont;
  final String bodyFont;
  final FontWeight displayWeight;
  final double displayLetterSpacing;
  final double eyebrowLetterSpacing;
  final double cardRadius;
  final bool displayUppercase;

  const ThemeVariant({
    required this.id,
    required this.name,
    required this.description,
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.ctaText,
    required this.displayFont,
    required this.bodyFont,
    required this.displayWeight,
    required this.displayLetterSpacing,
    required this.eyebrowLetterSpacing,
    required this.cardRadius,
    this.displayUppercase = false,
  });
}

/// The 4 candidates the user is comparing.
const List<ThemeVariant> kThemeCandidates = [
  ThemeVariant(
    id: 'gold',
    name: 'Gold',
    description: 'Current theme — iOS dark + gold accent.',
    background: Color(0xFF1C1C1E),
    surface: Color(0xFF2C2C2E),
    surface2: Color(0xFF3A3A3C),
    border: Color(0xFF3A3A3C),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF8E8E93),
    accent: Color(0xFFC8A96A),
    accent2: Color(0xFF8B7350),
    ctaText: Color(0xFF1A1300),
    displayFont: 'serif',
    bodyFont: 'sans-serif',
    displayWeight: FontWeight.w600,
    displayLetterSpacing: -0.5,
    eyebrowLetterSpacing: 3,
    cardRadius: 16,
  ),
  ThemeVariant(
    id: 'workshop',
    name: 'Workshop',
    description: 'Midnight blue + copper. Editorial atelier vibe.',
    background: Color(0xFF0A1220),
    surface: Color(0xFF131E30),
    surface2: Color(0xFF1A2740),
    border: Color(0xFF243349),
    text: Color(0xFFE8E6E0),
    muted: Color(0xFF8499B3),
    accent: Color(0xFFC08842),
    accent2: Color(0xFF8A5F2A),
    ctaText: Color(0xFF0A1220),
    displayFont: 'sans-serif',
    bodyFont: 'sans-serif',
    displayWeight: FontWeight.w400,
    displayLetterSpacing: 2,
    eyebrowLetterSpacing: 4,
    cardRadius: 6,
    displayUppercase: true,
  ),
  ThemeVariant(
    id: 'cabinet',
    name: 'Cabinet noir',
    description: 'Pure black + sang red. Museum / gallery vibe.',
    background: Color(0xFF050505),
    surface: Color(0xFF0F0F0F),
    surface2: Color(0xFF161616),
    border: Color(0xFF1F1F1F),
    text: Color(0xFFF5F5F5),
    muted: Color(0xFF707070),
    accent: Color(0xFFC8281E),
    accent2: Color(0xFF6E1810),
    ctaText: Color(0xFFF5F5F5),
    displayFont: 'sans-serif',
    bodyFont: 'sans-serif',
    displayWeight: FontWeight.w800,
    displayLetterSpacing: -1.2,
    eyebrowLetterSpacing: 6,
    cardRadius: 0,
  ),
  ThemeVariant(
    id: 'tarot',
    name: 'Tarot',
    description: 'Midnight purple + ceremonial gold. Esoteric serif.',
    background: Color(0xFF11091A),
    surface: Color(0xFF1E1232),
    surface2: Color(0xFF281840),
    border: Color(0xFF3A2454),
    text: Color(0xFFF0E8D8),
    muted: Color(0xFF9080A8),
    accent: Color(0xFFD4A82A),
    accent2: Color(0xFFA07F1C),
    ctaText: Color(0xFF11091A),
    displayFont: 'serif',
    bodyFont: 'serif',
    displayWeight: FontWeight.w600,
    displayLetterSpacing: 3,
    eyebrowLetterSpacing: 6,
    cardRadius: 8,
    displayUppercase: true,
  ),
];
