import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'state.dart';

/// Colour tokens taken straight from the design file.
class Pal {
  const Pal({
    required this.bg,
    required this.card,
    required this.ink,
    required this.mute,
    required this.acc,
    required this.acc2,
    required this.line,
  });

  final Color bg, card, ink, mute, acc, acc2, line;

  static const onAcc = Color(0xFF3B2F3F);

  static const light = Pal(
    bg: Color(0xFFFFF6F0),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF3B2F3F),
    mute: Color(0xFF6E5F73),
    acc: Color(0xFFF59BB0),
    acc2: Color(0xFFCDB8F5),
    line: Color(0xFFF0DDD5),
  );

  static const dark = Pal(
    bg: Color(0xFF1E1A2B),
    card: Color(0xFF2B2540),
    ink: Color(0xFFF6EDF8),
    mute: Color(0xFFBDB0CC),
    acc: Color(0xFFF59BB0),
    acc2: Color(0xFF8F7BD1),
    line: Color(0xFF3D3556),
  );

  /// Unlocked with the "Full year" achievement (also selectable under Settings > Theme).
  static const garden = Pal(
    bg: Color(0xFFF1FAF3),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF2F3F36),
    mute: Color(0xFF5F7368),
    acc: Color(0xFFF59BB0),
    acc2: Color(0xFFB7E3C9),
    line: Color(0xFFD5EBDD),
  );

  static Pal forBrightness(Brightness b) {
    final def = paletteById(app.garden ? 'garden' : app.palette);
    return b == Brightness.dark ? def.dark : def.light;
  }

  static Pal of(BuildContext c) => forBrightness(Theme.of(c).brightness);
}

/// A selectable colour theme with a light and a dark version.
class PaletteDef {
  const PaletteDef(this.id, this.name, this.light, this.dark);
  final String id, name;
  final Pal light, dark;
}

const List<PaletteDef> kPalettes = [
  PaletteDef('pawsie', 'Pawsie', Pal.light, Pal.dark),
  PaletteDef(
    'lavender',
    'Lavender',
    Pal(
      bg: Color(0xFFF7F3FF),
      card: Color(0xFFFFFFFF),
      ink: Color(0xFF2E2840),
      mute: Color(0xFF6B6385),
      acc: Color(0xFFB79CF2),
      acc2: Color(0xFFF5B8D4),
      line: Color(0xFFE6DDF7),
    ),
    Pal(
      bg: Color(0xFF1E1A2B),
      card: Color(0xFF2B2540),
      ink: Color(0xFFF6EDF8),
      mute: Color(0xFFBDB0CC),
      acc: Color(0xFFB79CF2),
      acc2: Color(0xFF7C5CCB),
      line: Color(0xFF3D3556),
    ),
  ),
  PaletteDef(
    'peach',
    'Peach',
    Pal(
      bg: Color(0xFFFFF3EA),
      card: Color(0xFFFFFFFF),
      ink: Color(0xFF3F2F2A),
      mute: Color(0xFF7A625A),
      acc: Color(0xFFFFA77A),
      acc2: Color(0xFFFFD27A),
      line: Color(0xFFF3DCCB),
    ),
    Pal(
      bg: Color(0xFF241B19),
      card: Color(0xFF332623),
      ink: Color(0xFFFBEFE8),
      mute: Color(0xFFD0B8AE),
      acc: Color(0xFFFFA77A),
      acc2: Color(0xFFC9884A),
      line: Color(0xFF4A3833),
    ),
  ),
  PaletteDef(
    'ocean',
    'Ocean',
    Pal(
      bg: Color(0xFFF0F8FF),
      card: Color(0xFFFFFFFF),
      ink: Color(0xFF22364A),
      mute: Color(0xFF5B7388),
      acc: Color(0xFF7DC4F0),
      acc2: Color(0xFFA8E6CF),
      line: Color(0xFFD5E6F2),
    ),
    Pal(
      bg: Color(0xFF14202B),
      card: Color(0xFF1E2E3D),
      ink: Color(0xFFEAF4FB),
      mute: Color(0xFFA9BFD0),
      acc: Color(0xFF7DC4F0),
      acc2: Color(0xFF4E9E86),
      line: Color(0xFF2D4256),
    ),
  ),
  PaletteDef(
    'garden',
    'Garden',
    Pal.garden,
    Pal(
      bg: Color(0xFF16221B),
      card: Color(0xFF203128),
      ink: Color(0xFFEAF6EE),
      mute: Color(0xFFA9C4B3),
      acc: Color(0xFF8FD6A8),
      acc2: Color(0xFF4E9E7A),
      line: Color(0xFF2F4A3B),
    ),
  ),
];

PaletteDef paletteById(String id) =>
    kPalettes.firstWhere((p) => p.id == id, orElse: () => kPalettes.first);

final Map<String, ThemeData> _themeCache = {};

/// Building a ThemeData (and its Google Fonts text theme) is expensive, and it used to
/// happen on every app-wide change. There are only a handful of combinations, so keep them.
ThemeData buildTheme(Brightness b) {
  final key = '${b.name}:${app.garden ? 'garden' : app.palette}';
  return _themeCache.putIfAbsent(key, () => _buildTheme(b));
}

ThemeData _buildTheme(Brightness b) {
  final p = Pal.forBrightness(b);
  final base = ThemeData(brightness: b, useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: p.acc,
    brightness: b,
  ).copyWith(primary: p.acc, onPrimary: Pal.onAcc, surface: p.card, onSurface: p.ink);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    textTheme: GoogleFonts.quicksandTextTheme(base.textTheme)
        .apply(bodyColor: p.ink, displayColor: p.ink),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.acc,
      selectionColor: p.acc.withAlpha(90),
    ),
  );
}
