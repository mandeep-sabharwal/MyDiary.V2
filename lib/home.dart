import 'package:flutter/material.dart';

import 'calendar.dart';
import 'cloud.dart';
import 'dialogs.dart';
import 'state.dart';
import 'settings.dart';
import 'stats.dart';
import 'widgets.dart';
import 'write.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _i = 0;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.015),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerRestore());
  }

  /// Right after signing in on an empty phone: restore the encrypted cloud backup.
  Future<void> _offerRestore() async {
    if (!mounted || !app.offerRestore) return;
    app.offerRestore = false;
    String? error;
    while (mounted) {
      final pass = await showDialog<String>(
        context: context,
        builder: (_) => PassphraseDialog(
          title: 'Restore your diary?',
          message:
              'We found an encrypted backup of your diary in the cloud. Enter your backup '
              'passphrase to bring your entries back. (Photos stay on the phone they were taken on.)',
          confirmLabel: 'Restore',
          cancelLabel: 'Not now',
          error: error,
        ),
      );
      if (pass == null || !mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final err = await cloud.enableBackup(pass);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (err == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Welcome back! ${cloud.lastSyncMessage}')));
        return;
      }
      error = err;
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Widget _tab(int i) {
    switch (i) {
      case 1:
        return const CalendarTab();
      case 2:
        return const StatsTab();
      default:
        return const SettingsTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The Write tab stays alive so a half-written entry is never lost.
                Offstage(
                  offstage: _i != 0,
                  child: TickerMode(enabled: _i == 0, child: const WriteTab()),
                ),
                // The others are built only while open, so closed tabs cost nothing
                // and do not rebuild whenever a setting changes.
                if (_i != 0) KeyedSubtree(key: ValueKey(_i), child: _tab(_i)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : PawNav(
              index: _i,
              onTap: (i) {
                if (i == _i) return;
                FocusScope.of(context).unfocus();
                setState(() => _i = i);
                _fade.forward(from: 0);
              },
            ),
    );
  }
}
