import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart' show kImgChar;
import 'theme.dart';

/// Formatting of a single character. Colours are ARGB ints, 0 = none.
@immutable
class Fmt {
  const Fmt({this.b = false, this.i = false, this.u = false, this.color = 0, this.hl = 0});

  final bool b, i, u;
  final int color, hl;

  static const plain = Fmt();

  Fmt copyWith({bool? b, bool? i, bool? u, int? color, int? hl}) => Fmt(
    b: b ?? this.b,
    i: i ?? this.i,
    u: u ?? this.u,
    color: color ?? this.color,
    hl: hl ?? this.hl,
  );

  int get flags => (b ? 1 : 0) | (i ? 2 : 0) | (u ? 4 : 0);

  @override
  bool operator ==(Object other) =>
      other is Fmt &&
      other.b == b &&
      other.i == i &&
      other.u == u &&
      other.color == color &&
      other.hl == hl;

  @override
  int get hashCode => Object.hash(b, i, u, color, hl);
}

class _Snap {
  _Snap(this.text, this.chars, this.sel, this.images);
  final String text;
  final List<Fmt> chars;
  final TextSelection sel;
  final List<String> images;
}

final RegExp _bulletRe = RegExp(r'^• ');
final RegExp _numRe = RegExp(r'^(\d+)\. ');

/// A TextEditingController that keeps per-character formatting
/// (bold / italic / underline / colour / highlight) and simple list lines.
class RichController extends TextEditingController {
  RichController({String text = '', List<List<int>>? runs, List<String>? images})
    : images = List<String>.of(images ?? const <String>[]),
      super(text: text) {
    _text = text;
    _chars = decodeRuns(text.length, runs);
    addListener(_onChange);
  }

  /// Photo file names, in the same order as the photo placeholders in the text.
  final List<String> images;

  /// Builds the widget shown for the photo at [index] (set by the editor screen).
  Widget Function(int index, String name)? imageBuilder;

  late String _text;
  late List<Fmt> _chars;
  Fmt typing = Fmt.plain; // formatting for newly typed characters
  TextSelection _sel = const TextSelection.collapsed(offset: -1);
  bool _busy = false;
  final List<_Snap> _history = [];
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  bool get canUndo => _history.isNotEmpty;

  // ---------- (de)serialising ----------
  static List<Fmt> decodeRuns(int length, List<List<int>>? runs) {
    final out = <Fmt>[];
    for (final r in runs ?? const <List<int>>[]) {
      if (r.length < 4) continue;
      final f = Fmt(b: r[1] & 1 != 0, i: r[1] & 2 != 0, u: r[1] & 4 != 0, color: r[2], hl: r[3]);
      for (var k = 0; k < r[0] && out.length < length; k++) {
        out.add(f);
      }
    }
    while (out.length < length) {
      out.add(Fmt.plain);
    }
    return out;
  }

  /// Run-length encoding: [length, flags, colour, highlight] per run.
  List<List<int>> encode() {
    final runs = <List<int>>[];
    var start = 0;
    for (var i = 1; i <= _chars.length; i++) {
      if (i == _chars.length || _chars[i] != _chars[start]) {
        final f = _chars[start];
        runs.add([i - start, f.flags, f.color, f.hl]);
        start = i;
      }
    }
    return runs;
  }

  // ---------- listener ----------
  void _onChange() {
    if (_busy) return;
    final t = value.text;
    if (t != _text) {
      _applyEdit(t);
    } else if (value.selection != _sel) {
      _syncTyping();
    }
    _sel = value.selection;
  }

  void _syncTyping() {
    final s = value.selection;
    if (!s.isValid || !s.isCollapsed || _chars.isEmpty) return;
    final at = s.baseOffset;
    if (at <= 0) {
      typing = _chars.first;
    } else {
      typing = _chars[math.min(at, _chars.length) - 1];
    }
  }

  void _applyEdit(String t) {
    final old = _text;
    final minLen = math.min(old.length, t.length);
    var p = 0;
    while (p < minLen && old.codeUnitAt(p) == t.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < minLen - p && old.codeUnitAt(old.length - 1 - s) == t.codeUnitAt(t.length - 1 - s)) {
      s++;
    }
    final removedImgs = kImgChar.allMatches(old.substring(p, old.length - s)).length;
    _push(coalesce: removedImgs == 0); // deleting a photo is always its own undo step
    if (removedImgs > 0) {
      final first = _imagesBefore(old, p);
      for (var k = 0; k < removedImgs && first < images.length; k++) {
        images.removeAt(first);
      }
    }
    final insLen = t.length - p - s;
    _chars.replaceRange(p, old.length - s, List<Fmt>.filled(insLen, typing));
    _text = t;
    if (t.isEmpty) typing = Fmt.plain;
    if (insLen == 1 && t[p] == '\n') _continueList(p);
  }

  /// Pressing Enter on a "• item" or "1. item" line starts the next item.
  void _continueList(int nl) {
    if (nl == 0) return;
    var ls = nl;
    while (ls > 0 && _text[ls - 1] != '\n') {
      ls--;
    }
    final prev = _text.substring(ls, nl);
    if (prev == '• ' || RegExp(r'^\d+\. $').hasMatch(prev)) {
      // empty item: end the list
      _replaceRange(ls, nl + 1, '', cursor: ls);
      return;
    }
    if (_bulletRe.hasMatch(prev)) {
      _replaceRange(nl + 1, nl + 1, '• ', cursor: nl + 3);
      return;
    }
    final m = _numRe.firstMatch(prev);
    if (m != null) {
      final next = '${int.parse(m.group(1)!) + 1}. ';
      _replaceRange(nl + 1, nl + 1, next, cursor: nl + 1 + next.length);
    }
  }

  void _edit(int start, int end, String ins) {
    _text = _text.replaceRange(start, end, ins);
    _chars.replaceRange(start, end, List<Fmt>.filled(ins.length, Fmt.plain));
  }

  void _setValue(int cursor) {
    _busy = true;
    value = TextEditingValue(
      text: _text,
      selection: TextSelection.collapsed(offset: cursor.clamp(0, _text.length)),
    );
    _sel = value.selection;
    _busy = false;
  }

  void _replaceRange(int start, int end, String ins, {required int cursor}) {
    _edit(start, end, ins);
    _setValue(cursor);
  }

  // ---------- inline photos ----------
  int _imagesBefore(String text, int pos) =>
      kImgChar.allMatches(text.substring(0, pos.clamp(0, text.length))).length;

  /// Puts a photo on its own line at the cursor.
  void insertImage(String name) {
    final sel = value.selection;
    final at = (sel.isValid ? sel.end : _text.length).clamp(0, _text.length);
    _push(coalesce: false);
    final prefix = (at > 0 && _text[at - 1] != '\n') ? '\n' : '';
    final ins = '$prefix$kImgChar\n';
    images.insert(_imagesBefore(_text, at), name);
    _replaceRange(at, at, ins, cursor: at + ins.length);
    notifyListeners();
  }

  /// Inserts plain text at the cursor (used for "Write about this" on the quote card).
  void insertPlain(String s) {
    final sel = value.selection;
    final at = (sel.isValid ? sel.end : _text.length).clamp(0, _text.length);
    _push(coalesce: false);
    _replaceRange(at, at, s, cursor: at + s.length);
    notifyListeners();
  }

  /// Removes the [index]-th photo (and its placeholder) from the text.
  void removeImageAt(int index) {
    var seen = -1;
    for (var i = 0; i < _text.length; i++) {
      if (_text[i] == kImgChar && ++seen == index) {
        _push(coalesce: false);
        if (index < images.length) images.removeAt(index);
        final cursor = value.selection.isValid ? value.selection.end : i;
        _replaceRange(i, i + 1, '', cursor: cursor > i ? cursor - 1 : cursor);
        notifyListeners();
        return;
      }
    }
  }

  // ---------- history ----------
  void _push({required bool coalesce}) {
    final now = DateTime.now();
    if (coalesce && _history.isNotEmpty && now.difference(_lastPush).inMilliseconds < 700) {
      _lastPush = now;
      return;
    }
    _history.add(_Snap(_text, List<Fmt>.of(_chars), _sel, List<String>.of(images)));
    if (_history.length > 60) _history.removeAt(0);
    _lastPush = now;
  }

  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    _text = s.text;
    _chars = List<Fmt>.of(s.chars);
    images
      ..clear()
      ..addAll(s.images);
    _busy = true;
    value = TextEditingValue(
      text: s.text,
      selection: s.sel.isValid && s.sel.end <= s.text.length
          ? s.sel
          : TextSelection.collapsed(offset: s.text.length),
    );
    _sel = value.selection;
    _busy = false;
    _syncTyping();
    notifyListeners();
  }

  void reset() {
    _busy = true;
    _text = '';
    _chars = [];
    images.clear();
    _history.clear();
    typing = Fmt.plain;
    value = TextEditingValue.empty;
    _sel = value.selection;
    _busy = false;
  }

  // ---------- character formatting ----------
  (int, int)? get _range {
    final s = value.selection;
    if (!s.isValid || s.isCollapsed) return null;
    final a = s.start.clamp(0, _chars.length);
    final b = s.end.clamp(0, _chars.length);
    return a >= b ? null : (a, b);
  }

  bool isOn(bool Function(Fmt f) test) {
    final r = _range;
    if (r == null) return test(typing);
    for (var i = r.$1; i < r.$2; i++) {
      if (!test(_chars[i])) return false;
    }
    return true;
  }

  void _apply(Fmt Function(Fmt f, bool on) change, bool Function(Fmt f) test) {
    final r = _range;
    if (r == null) {
      typing = change(typing, !test(typing));
    } else {
      final on = !isOn(test);
      _push(coalesce: false);
      for (var i = r.$1; i < r.$2; i++) {
        _chars[i] = change(_chars[i], on);
      }
    }
    notifyListeners();
  }

  void toggleBold() => _apply((f, on) => f.copyWith(b: on), (f) => f.b);
  void toggleItalic() => _apply((f, on) => f.copyWith(i: on), (f) => f.i);
  void toggleUnderline() => _apply((f, on) => f.copyWith(u: on), (f) => f.u);

  /// Tap a colour: applies it, or clears it if it is already applied.
  void setColor(int c) =>
      _apply((f, on) => f.copyWith(color: on ? c : 0), (f) => f.color == c && c != 0);

  void setDefaultColor() {
    final r = _range;
    if (r == null) {
      typing = typing.copyWith(color: 0);
    } else {
      _push(coalesce: false);
      for (var i = r.$1; i < r.$2; i++) {
        _chars[i] = _chars[i].copyWith(color: 0);
      }
    }
    notifyListeners();
  }

  void setHighlight(int c) => _apply((f, on) => f.copyWith(hl: on ? c : 0), (f) => f.hl == c);

  // ---------- lists ----------
  String _lineAt(int pos) {
    final e = _text.indexOf('\n', pos);
    return _text.substring(pos, e < 0 ? _text.length : e);
  }

  bool get bulletsOn => _currentLinesAll(_bulletRe);
  bool get numbersOn => _currentLinesAll(_numRe);

  List<int> _lineStarts() {
    final sel = value.selection;
    final len = _text.length;
    final a = (sel.isValid ? sel.start : len).clamp(0, len);
    final b = (sel.isValid ? sel.end : len).clamp(0, len);
    var ls = a;
    while (ls > 0 && _text[ls - 1] != '\n') {
      ls--;
    }
    final starts = <int>[ls];
    for (var i = ls; i < b; i++) {
      if (_text[i] == '\n' && i + 1 < b) starts.add(i + 1);
    }
    return starts;
  }

  bool _currentLinesAll(RegExp re) {
    if (_text.isEmpty) return false;
    return _lineStarts().every((s) => re.hasMatch(_lineAt(s)));
  }

  void toggleList({required bool numbered}) {
    final re = numbered ? _numRe : _bulletRe;
    final other = numbered ? _bulletRe : _numRe;
    final starts = _lineStarts();
    final allHave = _text.isNotEmpty && starts.every((s) => re.hasMatch(_lineAt(s)));
    _push(coalesce: false);
    var off = 0;
    var n = 1;
    var lastPos = 0;
    for (final s in starts) {
      final pos = s + off;
      lastPos = pos;
      final line = _lineAt(pos);
      final m = re.firstMatch(line);
      if (allHave) {
        _edit(pos, pos + m!.end, '');
        off -= m.end;
      } else if (m == null) {
        final o = other.firstMatch(line);
        if (o != null) {
          _edit(pos, pos + o.end, '');
          off -= o.end;
        }
        final mk = numbered ? '$n. ' : '• ';
        _edit(pos, pos, mk);
        off += mk.length;
        n++;
      }
    }
    _setValue(lastPos + _lineAt(lastPos).length);
    notifyListeners();
  }

  // ---------- rendering ----------
  TextStyle _styleFor(Fmt f) => TextStyle(
    fontWeight: f.b ? FontWeight.w700 : null,
    fontStyle: f.i ? FontStyle.italic : null,
    decoration: f.u ? TextDecoration.underline : null,
    color: f.color != 0 ? Color(f.color) : (f.hl != 0 ? Pal.onAcc : null),
    backgroundColor: f.hl != 0 ? Color(f.hl) : null,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final txt = text;
    if (txt.isEmpty || _chars.length != txt.length) {
      return TextSpan(style: style, text: txt);
    }
    final children = <InlineSpan>[];
    var imgIndex = 0;
    var start = 0;
    for (var i = 1; i <= txt.length; i++) {
      if (i == txt.length || _chars[i] != _chars[start]) {
        final st = _styleFor(_chars[start]);
        var seg = txt.substring(start, i);
        while (true) {
          final k = seg.indexOf(kImgChar);
          if (k < 0) break;
          if (k > 0) children.add(TextSpan(text: seg.substring(0, k), style: st));
          final idx = imgIndex++;
          final w = (imageBuilder != null && idx < images.length)
              ? imageBuilder!(idx, images[idx])
              : const SizedBox(width: 1, height: 1);
          children.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: w));
          seg = seg.substring(k + 1);
        }
        if (seg.isNotEmpty) children.add(TextSpan(text: seg, style: st));
        start = i;
      }
    }
    return TextSpan(style: style, children: children);
  }
}

const List<int> kTextColors = [0xFFE0457B, 0xFF7C5CCB, 0xFF2E9E75, 0xFFD98A1F, 0xFF3A86E0];
const List<int> kHighlights = [0xFFFFE9A8, 0xFFFFD6E4, 0xFFD6F0E3];

/// Undo / B / I / U / lists / colours / highlights, as in the design.
class RichToolbar extends StatefulWidget {
  const RichToolbar({super.key, required this.controller});
  final RichController controller;
  @override
  State<RichToolbar> createState() => _RichToolbarState();
}

class _RichToolbarState extends State<RichToolbar> {
  bool _showColors = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final p = Pal.of(context);

    Widget btn(Widget child, bool on, VoidCallback? onTap, String tip) => Tooltip(
      message: tip,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Material(
          color: on ? p.acc : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: on ? Pal.onAcc : p.ink,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      size: 22,
                      color: onTap == null ? p.mute.withAlpha(120) : (on ? Pal.onAcc : p.ink),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Widget divider() => Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.only(left: 2, right: 6),
      color: p.line,
    );

    Widget swatch(int argb, {required bool round, required bool on, required VoidCallback tap}) =>
        GestureDetector(
          onTap: tap,
          child: Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: argb == 0 ? p.ink : Color(argb),
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: round ? null : BorderRadius.circular(10),
              border: Border.all(color: on ? p.acc : p.line, width: on ? 3 : 1),
            ),
            child: on ? Icon(Icons.check, size: 16, color: round ? Colors.white : Pal.onAcc) : null,
          ),
        );

    return TextFieldTapRegion(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  btn(const Icon(Icons.undo), false, c.canUndo ? c.undo : null, 'Undo'),
                  divider(),
                  btn(const Text('B'), c.isOn((f) => f.b), c.toggleBold, 'Bold'),
                  btn(
                    const Text('I', style: TextStyle(fontStyle: FontStyle.italic)),
                    c.isOn((f) => f.i),
                    c.toggleItalic,
                    'Italic',
                  ),
                  btn(
                    const Text('U', style: TextStyle(decoration: TextDecoration.underline)),
                    c.isOn((f) => f.u),
                    c.toggleUnderline,
                    'Underline',
                  ),
                  divider(),
                  btn(
                    const Icon(Icons.format_list_bulleted),
                    c.bulletsOn,
                    () => c.toggleList(numbered: false),
                    'Bullet list',
                  ),
                  btn(
                    const Icon(Icons.format_list_numbered),
                    c.numbersOn,
                    () => c.toggleList(numbered: true),
                    'Numbered list',
                  ),
                  divider(),
                  btn(
                    const Icon(Icons.palette_outlined),
                    _showColors,
                    () => setState(() => _showColors = !_showColors),
                    'Colours',
                  ),
                ],
              ),
            ),
            if (_showColors)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      swatch(
                        0,
                        round: true,
                        on: c.isOn((f) => f.color == 0),
                        tap: c.setDefaultColor,
                      ),
                      for (final col in kTextColors)
                        swatch(
                          col,
                          round: true,
                          on: c.isOn((f) => f.color == col),
                          tap: () => c.setColor(col),
                        ),
                      Container(
                        width: 1,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        color: p.line,
                      ),
                      for (final col in kHighlights)
                        swatch(
                          col,
                          round: false,
                          on: c.isOn((f) => f.hl == col),
                          tap: () => c.setHighlight(col),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
