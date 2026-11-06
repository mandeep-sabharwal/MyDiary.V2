import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'state.dart';
import 'theme.dart';

/// Shows a photo that is stored encrypted on the device.
class SecureImage extends StatefulWidget {
  const SecureImage({
    super.key,
    required this.name,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth = 700,
  });
  final String name;
  final double? width, height;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  State<SecureImage> createState() => _SecureImageState();
}

class _SecureImageState extends State<SecureImage> {
  late Future<Uint8List?> _bytes = app.photoBytes(widget.name);

  @override
  void didUpdateWidget(SecureImage old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _bytes = app.photoBytes(widget.name);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget box(Widget? child) => Container(
      width: widget.width,
      height: widget.height,
      color: p.line,
      alignment: Alignment.center,
      child: child,
    );
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return box(null);
        final b = snap.data;
        if (b == null) {
          return box(
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined, color: p.mute),
                  Text(
                    'Photo is on another device',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.mute, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        }
        return Image.memory(
          b,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => box(Icon(Icons.broken_image_outlined, color: p.mute)),
        );
      },
    );
  }
}

/// Full-screen, pinch-to-zoom viewer.
Future<void> showPhotoViewer(BuildContext context, String name) async {
  final bytes = await app.photoBytes(name);
  if (bytes == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(maxScale: 5, child: Center(child: Image.memory(bytes))),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Close',
                color: Colors.white,
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
