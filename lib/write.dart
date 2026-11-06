import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'mochi.dart';
import 'models.dart';
import 'rich.dart';
import 'secure_image.dart';
import 'state.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets.dart';

/// The "Write" tab: a fresh entry for today.
class WriteTab extends StatelessWidget {
  const WriteTab({super.key});
  @override
  Widget build(BuildContext context) => const EntryForm();
}

/// Pushed when you open an existing entry from the Calendar.
class EntryEditorScreen extends StatelessWidget {
  const EntryEditorScreen({super.key, required this.entry});
  final Entry entry;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = Pal.of(ctx);
        return AlertDialog(
          backgroundColor: p.card,
          surfaceTintColor: Colors.transparent,
          title: const Text('Delete this entry?'),
          content: const Text('This page (and its photos) will be removed from your diary.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
          ],
        );
      },
    );
    if (ok == true) {
      await app.deleteEntry(entry);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'Entry',
              trailing: IconButton(
                tooltip: 'Delete entry',
                onPressed: () => _delete(context),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
            Expanded(
              child: EntryForm(entry: entry, onSaved: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}

class EntryForm extends StatefulWidget {
  const EntryForm({super.key, this.entry, this.onSaved});
  final Entry? entry;
  final VoidCallback? onSaved;
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  late Mood _mood;
  late final TextEditingController _title;
  late final RichController _body;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();
  final Set<String> _imported = {}; // photos added in this session (for clean-up)
  bool _saved = false;
  late List<String> _stickers;
  final Stopwatch _sw = Stopwatch();
  int _baseSecs = 0;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _mood = e?.mood ?? Mood.happy;
    _title = TextEditingController(text: e?.title ?? '');
    // Entries from older versions kept photos in a strip; give each one a spot in the text.
    var body = e?.body ?? '';
    final photos = e?.photos ?? const <String>[];
    final have = kImgChar.allMatches(body).length;
    if (photos.length > have) {
      if (body.isNotEmpty && !body.endsWith('\n')) body += '\n';
      body += '$kImgChar\n' * (photos.length - have);
    }
    _body = RichController(text: body, runs: e?.runs, images: photos);
    _body.imageBuilder = _buildInline;
    _body.addListener(_onBodyChanged);
    _titleFocus.addListener(_onFocus);
    _bodyFocus.addListener(_onFocus);
    _stickers = List.of(e?.stickers ?? const <String>[]);
    _baseSecs = e?.seconds ?? 0;
  }

  void _onBodyChanged() {
    // Only the timer needs to know. The word count and toolbar listen to the controller
    // themselves, so typing no longer rebuilds the whole screen.
    if (!_sw.isRunning && _body.text.isNotEmpty) _sw.start();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  Widget _buildInline(int index, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => showPhotoViewer(context, name),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SecureImage(name: name, width: 220, height: 150, cacheWidth: 440),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _body.removeImageAt(index),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Deletes photo files that are no longer part of the entry.
  void _cleanupPhotos() {
    final keep = _body.images.toSet();
    for (final n in _imported) {
      if (!keep.contains(n)) app.deletePhoto(n);
    }
    for (final n in widget.entry?.photos ?? const <String>[]) {
      if (!keep.contains(n)) app.deletePhoto(n);
    }
  }

  @override
  void dispose() {
    if (!_saved) {
      for (final n in _imported) {
        app.deletePhoto(n); // added but never saved
      }
    }
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  // ---------- adding photos / stickers ----------
  Future<void> _addMenu() async {
    FocusScope.of(context).unfocus();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Pal.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final p = Pal.of(ctx);
        Widget row(IconData icon, String title, String sub, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: p.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: p.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(ctx, value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          Text(sub, style: TextStyle(color: p.mute, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Add to your entry',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                row(Icons.photo_camera_outlined, 'Take a photo', 'Use your camera', 'camera'),
                row(
                  Icons.photo_library_outlined,
                  'Photo library',
                  'Pick up to 10 photos',
                  'gallery',
                ),
                row(
                  Icons.emoji_emotions_outlined,
                  'Mochi stickers',
                  'Decorate with reactions',
                  'stickers',
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice == 'stickers') {
      await _pickSticker();
    } else {
      await _pickPhotos(camera: choice == 'camera');
    }
  }

  Future<void> _pickPhotos({required bool camera}) async {
    final room = 10 - _body.images.length;
    if (room <= 0) {
      toast(context, 'Up to 10 photos per entry.');
      return;
    }
    app.suppressLock = true; // the camera pauses the app; do not lock on return
    try {
      final picker = ImagePicker();
      final List<XFile> files;
      if (camera) {
        final f = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1600,
        );
        files = f == null ? <XFile>[] : <XFile>[f];
      } else {
        files = await picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
      }
      for (final f in files.take(room)) {
        final n = await app.importPhoto(f);
        _imported.add(n);
        _body.insertImage(n);
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) toast(context, 'Could not open ${camera ? 'the camera' : 'your photos'}.');
    } finally {
      app.suppressLock = false;
    }
  }

  Future<void> _pickSticker() async {
    final picked = await showDialog<Mood>(
      context: context,
      builder: (ctx) {
        final p = Pal.of(ctx);
        return AlertDialog(
          backgroundColor: p.card,
          surfaceTintColor: Colors.transparent,
          title: const Text('Mochi stickers'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in Mood.values)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(ctx, m),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Mochi(mood: m, size: 48),
                          Text(m.label, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      if (_stickers.length >= 6) {
        toast(context, 'Six stickers is plenty!');
      } else {
        setState(() => _stickers.add(picked.name));
      }
    }
  }

  // ---------- saving ----------
  void _reset() {
    _title.clear();
    _body.reset();
    _imported.clear();
    _saved = false;
    _stickers = [];
    _sw
      ..stop()
      ..reset();
    _baseSecs = 0;
    _mood = Mood.happy;
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty && _body.text.trim().isEmpty && _body.images.isEmpty) {
      toast(context, 'Write a little something first.');
      return;
    }
    FocusScope.of(context).unfocus();
    final before = app.unlockedIds;
    final secs = _baseSecs + _sw.elapsed.inSeconds;

    if (_editing) {
      final e = widget.entry!;
      e
        ..title = title
        ..body = _body.text
        ..runs = _body.encode()
        ..mood = _mood
        ..photos = List.of(_body.images)
        ..stickers = List.of(_stickers)
        ..seconds = secs;
      app.updateEntry(e);
      _cleanupPhotos();
      _saved = true;
      toast(context, 'Changes saved.');
      widget.onSaved?.call();
      return;
    }

    app.addEntry(
      Entry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        title: title,
        body: _body.text,
        runs: _body.encode(),
        mood: _mood,
        photos: List.of(_body.images),
        stickers: List.of(_stickers),
        seconds: secs,
      ),
    );
    _cleanupPhotos();
    _saved = true;
    _celebrate(before);
    _reset();
    setState(() {});
    widget.onSaved?.call();
  }

  void _celebrate(Set<String> before) {
    final after = app.unlockedIds;
    final fresh = kAchievements
        .where((a) => after.contains(a.id) && !before.contains(a.id))
        .toList();
    if (fresh.isEmpty) {
      final streak = app.stats.current;
      toast(
        context,
        streak > 1 ? '$streak-day streak! Mochi is so proud.' : 'Entry saved. Mochi is happy!',
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final p = Pal.of(ctx);
        return AlertDialog(
          backgroundColor: p.card,
          surfaceTintColor: Colors.transparent,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Mochi(mood: Mood.surprised, size: 96),
              const SizedBox(height: 8),
              for (final a in fresh) ...[
                Text(
                  'New badge: ${a.title}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Reward: ${rewardById(a.rewardId)?.name ?? ''}',
                  style: TextStyle(color: p.mute),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Yay!', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final date = _editing ? widget.entry!.createdAt : DateTime.now();
    final typingMode = _titleFocus.hasFocus || _bodyFocus.hasFocus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          if (!typingMode) ...[
            Row(
              children: [
                Mochi(mood: _mood, size: 64, dressed: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: p.card,
                      border: Border.all(color: p.line),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(longDate(date), style: TextStyle(color: p.mute, fontSize: 13)),
                        Text(
                          _editing ? 'Edit entry' : 'How was your day?',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: Mood.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m = Mood.values[i];
                  final sel = m == _mood;
                  return SizedBox(
                    width: 68,
                    child: Material(
                      color: sel ? p.acc : p.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: sel ? p.acc : p.line),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() => _mood = m),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Mochi(mood: m, size: 40),
                            const SizedBox(height: 2),
                            Text(
                              m.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sel ? Pal.onAcc : p.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: PawCard(
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    focusNode: _titleFocus,
                    onTapOutside: (_) {},
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Give today a title',
                      hintStyle: TextStyle(color: p.mute.withAlpha(150)),
                    ),
                  ),
                  Divider(color: p.line, height: 16),
                  RichToolbar(controller: _body),
                  const SizedBox(height: 4),
                  Expanded(
                    child: TextField(
                      controller: _body,
                      focusNode: _bodyFocus,
                      onTapOutside: (_) {},
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Dear diary...',
                        hintStyle: TextStyle(color: p.mute.withAlpha(150)),
                      ),
                    ),
                  ),
                  if (_stickers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (var i = 0; i < _stickers.length; i++)
                            GestureDetector(
                              onTap: () => setState(() => _stickers.removeAt(i)),
                              child: Mochi(face: _stickers[i], size: 36),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Add photos or stickers',
                        onPressed: _addMenu,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: _body,
                          builder: (_, __) => Text(
                            '${countWords(_body.text)} words',
                            style: TextStyle(color: p.mute, fontSize: 13),
                          ),
                        ),
                      ),
                      PawBtn(
                        accent: true,
                        height: 48,
                        radius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        onTap: _save,
                        child: Text(
                          _editing ? 'Save changes' : 'Save entry',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
