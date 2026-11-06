import 'package:flutter/material.dart';

import 'biometric.dart';
import 'mochi.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class _PinPad extends StatelessWidget {
  const _PinPad({required this.length, required this.onDigit, required this.onDelete});
  final int length;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget key(String d) {
      if (d.isEmpty) return const SizedBox(width: 72, height: 72);
      if (d == 'del') {
        return SizedBox(
          width: 72,
          height: 72,
          child: IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: Icon(Icons.backspace_outlined, color: p.ink),
          ),
        );
      }
      return Material(
        color: p.card,
        shape: CircleBorder(side: BorderSide(color: p.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onDigit(d),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(
                d,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: p.ink),
              ),
            ),
          ),
        ),
      );
    }

    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < length ? p.acc : Colors.transparent,
                  border: i < length ? null : Border.all(color: p.mute, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < r.length; i++) ...[
                  if (i > 0) const SizedBox(width: 24),
                  key(r[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Shown on launch / resume when the passcode lock is on. Always dark.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    if (app.biometricOn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
    }
  }

  Future<void> _bio() async {
    if (!app.biometricOn) return;
    app.suppressLock = true;
    final ok = await Biometric.authenticate('Unlock your diary');
    app.suppressLock = false;
    if (ok) app.unlock();
  }

  void _digit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      if (app.verifyPasscode(_pin)) {
        app.unlock();
      } else {
        Future.delayed(const Duration(milliseconds: 180), () {
          if (!mounted) return;
          setState(() {
            _pin = '';
            _error = 'That passcode is not right. Try again.';
          });
        });
      }
    }
  }

  Future<void> _forgot(BuildContext ctx) async {
    String? error;
    while (true) {
      final password = await showDialog<String>(
        context: ctx,
        builder: (_) => _ForgotDialog(error: error),
      );
      if (password == null || !mounted) return;
      if (app.resetPasscodeWithPassword(password)) return;
      error = 'Wrong password';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(Brightness.dark),
      child: Builder(
        builder: (ctx) {
          final p = Pal.of(ctx);
          return Scaffold(
            backgroundColor: p.bg,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Mochi(mood: Mood.sleepy, size: 96),
                      const SizedBox(height: 10),
                      const Text(
                        'Mochi is guarding',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter your passcode to open your diary',
                        style: TextStyle(color: p.mute, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 22,
                        child: Text(
                          _error ?? '',
                          style: const TextStyle(color: Color(0xFFF59BB0), fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PinPad(
                        length: _pin.length,
                        onDigit: _digit,
                        onDelete: () => setState(() {
                          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
                        }),
                      ),
                      const SizedBox(height: 8),
                      if (app.biometricOn)
                        TextButton.icon(
                          onPressed: _bio,
                          icon: Icon(Icons.fingerprint, color: p.acc),
                          label: Text(
                            'Use fingerprint or face',
                            style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
                          ),
                        ),
                      TextButton(
                        onPressed: () => _forgot(ctx),
                        child: Text(
                          'Forgot passcode?',
                          style: TextStyle(
                            color: p.ink,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Choose + confirm a new 4 digit passcode. Pops with the code, or null.
class PasscodeSetupScreen extends StatefulWidget {
  const PasscodeSetupScreen({super.key});
  @override
  State<PasscodeSetupScreen> createState() => _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends State<PasscodeSetupScreen> {
  String _pin = '';
  String? _first;
  String? _msg;

  void _digit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _msg = null;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        if (_first == null) {
          setState(() {
            _first = _pin;
            _pin = '';
          });
        } else if (_first == _pin) {
          Navigator.pop(context, _pin);
        } else {
          setState(() {
            _first = null;
            _pin = '';
            _msg = 'Those did not match. Let us start again.';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'Passcode'),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Mochi(mood: Mood.calm, size: 84),
                      const SizedBox(height: 10),
                      Text(
                        _first == null ? 'Choose a passcode' : 'Confirm your passcode',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '4 digits. Mochi will guard your diary with it.',
                        style: TextStyle(color: p.mute, fontSize: 13),
                      ),
                      SizedBox(
                        height: 30,
                        child: Center(
                          child: Text(
                            _msg ?? '',
                            style: const TextStyle(color: Color(0xFFF0607E), fontSize: 13),
                          ),
                        ),
                      ),
                      _PinPad(
                        length: _pin.length,
                        onDigit: _digit,
                        onDelete: () => setState(() {
                          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Forgot passcode?": asks for the account password. Owns its own text controller.
class _ForgotDialog extends StatefulWidget {
  const _ForgotDialog({this.error});
  final String? error;
  @override
  State<_ForgotDialog> createState() => _ForgotDialogState();
}

class _ForgotDialogState extends State<_ForgotDialog> {
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
      title: const Text('Forgot passcode?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter your account password to turn the passcode off.',
            style: TextStyle(color: p.mute),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctl,
            obscureText: true,
            decoration: pawInput(p, 'Account password'),
          ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(widget.error!, style: const TextStyle(color: Color(0xFFF0607E))),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctl.text),
          child: const Text('Turn off'),
        ),
      ],
    );
  }
}
