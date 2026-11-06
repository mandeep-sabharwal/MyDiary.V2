import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'mochi_art.dart';
import 'models.dart';
import 'state.dart';

final Map<String, String> _cache = {};

/// True if the reward is drawn on Mochi (the Garden theme is not).
bool kMochiHasArt(String id) => kMochiAccessories.containsKey(id);

/// Builds the SVG for Mochi with a given face and accessories.
String buildMochi(String face, List<String> items) {
  final key = '$face|${items.join(',')}';
  return _cache.putIfAbsent(key, () {
    final acc = items.map((i) => kMochiAccessories[i] ?? '').join();
    final vb = items.isEmpty ? '0 0 100 100' : '0 -12 100 124';
    final f = kMochiFaces[face] ?? kMochiFaces['happy']!;
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$vb">'
        '$kMochiBase$kMochiGroupOpen$f$acc</g></svg>';
  });
}

class Mochi extends StatelessWidget {
  const Mochi({
    super.key,
    this.mood = Mood.happy,
    this.face,
    this.size = 64,
    this.dressed = false,
    this.items,
  });

  final Mood mood;

  /// Overrides [mood], e.g. 'wink'.
  final String? face;
  final double size;

  /// Wear whatever is equipped in the Wardrobe.
  final bool dressed;

  /// Explicit accessory ids (used by the Wardrobe previews).
  final List<String>? items;

  @override
  Widget build(BuildContext context) {
    final its = items ?? (dressed ? app.equippedFragmentIds : const <String>[]);
    final svg = buildMochi(face ?? mood.name, its);
    final h = its.isEmpty ? size : size * 1.24;
    return SvgPicture.string(
      svg,
      width: size,
      height: h,
      semanticsLabel: 'Mochi the cat, ${face ?? mood.name}',
    );
  }
}
