import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// Asks for the backup passphrase. It owns its text controller, so the controller
/// is only disposed once the dialog has fully left the screen.
class PassphraseDialog extends StatefulWidget {
  const PassphraseDialog({
    super.key,
    this.title = 'Backup passphrase',
    this.message =
        'Your entries are locked with this passphrase on your phone before they are '
        'uploaded, so nobody else can read them. Write it down: if you forget it, '
        'the backup cannot be recovered. You will need it on a new phone.',
    this.confirmLabel = 'Turn on',
    this.error,
    this.cancelLabel = 'Cancel',
  });

  final String title, message, confirmLabel, cancelLabel;
  final String? error;

  @override
  State<PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<PassphraseDialog> {
  final TextEditingController _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AlertDialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.message, style: TextStyle(color: p.mute, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctl,
              obscureText: true,
              decoration: pawInput(p, 'At least 8 characters'),
            ),
            if (widget.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.error!,
                  style: const TextStyle(color: Color(0xFFF0607E), fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.cancelLabel)),
        TextButton(
          onPressed: () {
            if (_ctl.text.length >= 8) Navigator.pop(context, _ctl.text);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
