import 'package:flutter/material.dart';

import 'theme.dart';

class PawCard extends StatelessWidget {
  const PawCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.radius = 20,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Pill-ish button with a 44px minimum touch target, as in the design.
class PawBtn extends StatelessWidget {
  const PawBtn({
    super.key,
    required this.child,
    required this.onTap,
    this.accent = false,
    this.selected = false,
    this.flat = false,
    this.minWidth = 44,
    this.height = 44,
    this.radius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool accent, selected, flat;
  final double minWidth, height, radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final on = accent || selected;
    final r = BorderRadius.circular(radius);
    return Material(
      color: flat ? Colors.transparent : (on ? p.acc : p.card),
      shape: RoundedRectangleBorder(
        borderRadius: r,
        side: flat ? BorderSide.none : BorderSide(color: on ? p.acc : p.line),
      ),
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth, minHeight: height),
          child: Padding(
            padding: padding,
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: DefaultTextStyle.merge(
                style: TextStyle(fontWeight: FontWeight.w700, color: on ? Pal.onAcc : p.ink),
                child: IconTheme.merge(
                  data: IconThemeData(color: on ? Pal.onAcc : p.ink),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration pawInput(Pal p, String hint) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.mute.withAlpha(170)),
    filled: true,
    fillColor: p.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: b(p.line),
    enabledBorder: b(p.line),
    focusedBorder: b(p.acc, 2),
  );
}

class PawNav extends StatelessWidget {
  const PawNav({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.edit_outlined, Icons.edit, 'Write'),
    (Icons.calendar_today_outlined, Icons.calendar_today, 'Calendar'),
    (Icons.bar_chart_rounded, Icons.bar_chart_rounded, 'Stats'),
    (Icons.tune, Icons.tune, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < _items.length; i++)
              _NavItem(
                icon: i == index ? _items[i].$2 : _items[i].$1,
                label: _items[i].$3,
                selected: i == index,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon only when idle; the open tab grows into a pill that shows its name.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = selected ? Pal.onAcc : p.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: 48,
          constraints: const BoxConstraints(minWidth: 48),
          padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
          decoration: BoxDecoration(
            color: selected ? p.acc : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: Icon(icon, size: 22, color: fg),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back button + title row used on pushed screens.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          PawBtn(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(width: 44, child: trailing),
        ],
      ),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
