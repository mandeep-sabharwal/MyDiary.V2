import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'biometric.dart';
import 'brand_links.dart';
import 'cloud.dart';
import 'dialogs.dart';
import 'lock.dart';
import 'pdf_export.dart';
import 'reminders.dart';
import 'state.dart';
import 'theme.dart';
import 'wardrobe.dart';
import 'widgets.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<bool> _confirm(BuildContext context, String title, String body, String yes) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = Pal.of(ctx);
        return AlertDialog(
          backgroundColor: p.card,
          surfaceTintColor: Colors.transparent,
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
          ],
        );
      },
    );
    return r == true;
  }

  Future<void> _toggleReminder(BuildContext context) async {
    if (app.reminderOn) {
      app.setReminderOn(false);
      return;
    }
    final ok = await reminders.requestPermission();
    if (!context.mounted) return;
    if (!ok) {
      toast(
        context,
        'Could not turn on reminders: ${reminders.lastError ?? 'permission denied'}\n'
        'Allow notifications for the app in Android settings, and run the Android setup step from the README.',
      );
      return;
    }
    app.setReminderOn(true);
    final t = TimeOfDay(hour: app.reminderMinutes ~/ 60, minute: app.reminderMinutes % 60);
    toast(context, 'Mochi will remind you every evening at ${t.format(context)}.');
  }

  /// Signing out removes the diary from this phone, so make that safe:
  /// confirm first, and if cloud backup is on, upload everything before deleting.
  Future<void> _signOut(BuildContext context) async {
    final cloudOn = cloud.available && cloud.user != null && app.cloudBackup;
    final ok = await _confirm(
      context,
      'Sign out?',
      cloudOn
          ? 'Your diary is safe in your cloud backup. Signing out removes it from this phone. '
                'Sign in again and enter your passphrase to bring it back.'
          : 'Signing out removes your diary from this phone. It is NOT backed up online, so it '
                'will be gone for good. Export a PDF first if you want to keep it.',
      'Sign out',
    );
    if (!ok || !context.mounted) return;
    if (cloudOn) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await cloud.syncNow();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!cloud.lastSyncOk) {
        final force = await _confirm(
          context,
          'Backup did not finish',
          'Your latest entries could not be uploaded (${cloud.lastSyncMessage}). '
              'Sign out anyway and lose anything that is not backed up?',
          'Sign out anyway',
        );
        if (!force) return;
      }
    }
    await cloud.signOut();
    await app.deleteEverything();
  }

  /// Developer aid: long-press "Daily reminder" to see why reminders might not fire.
  Future<void> _reminderStatus(BuildContext context) async {
    final msg = await reminders.diagnose();
    if (context.mounted) toast(context, msg);
  }

  Future<void> _toggleBiometric(BuildContext context) async {
    if (app.biometricOn) {
      app.setBiometric(false);
      return;
    }
    if (!app.hasPasscode) {
      toast(
        context,
        'Turn on the passcode lock first. It is the fallback if the fingerprint fails.',
      );
      return;
    }
    app.suppressLock = true;
    final ok = await Biometric.authenticate('Confirm to turn on fingerprint unlock');
    app.suppressLock = false;
    if (ok) {
      app.setBiometric(true);
    } else if (context.mounted) {
      toast(context, 'Could not confirm your fingerprint or face.');
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    String? error;
    try {
      await exportDiaryPdf();
    } catch (e) {
      error = '$e';
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (error != null) toast(context, 'Could not make the PDF: $error');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Pal.of(context);

        Widget row(String label, Widget trailing, {VoidCallback? onLongPress}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: onLongPress,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              trailing,
            ],
          ),
        );

        Widget themeBtn(String label, ThemeMode m) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PawBtn(
              selected: app.themeMode == m,
              height: 46,
              onTap: () => app.setThemeMode(m),
              child: Text(label),
            ),
          ),
        );

        final t = TimeOfDay(hour: app.reminderMinutes ~/ 60, minute: app.reminderMinutes % 60);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          children: [
            const Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            if (app.userName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Signed in as ${app.userName}',
                  style: TextStyle(color: p.mute, fontSize: 13),
                ),
              ),
            const SizedBox(height: 14),
            PawCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      themeBtn('Light', ThemeMode.light),
                      themeBtn('Dark', ThemeMode.dark),
                      themeBtn('Auto', ThemeMode.system),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            PawCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final d in kPalettes)
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: GestureDetector(
                              onTap: () => app.setPalette(d.id),
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [d.light.acc, d.light.acc2],
                                      ),
                                      border: Border.all(
                                        color: app.palette == d.id && !app.garden ? p.ink : p.line,
                                        width: app.palette == d.id && !app.garden ? 3 : 1,
                                      ),
                                    ),
                                    child: app.palette == d.id && !app.garden
                                        ? const Icon(Icons.check, color: Pal.onAcc)
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(d.name, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: p.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: p.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WardrobeScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.checkroom_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wardrobe',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Text(
                              'Dress Mochi up with your rewards',
                              style: TextStyle(color: p.mute, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            PawCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  row(
                    'Daily reminder',
                    PawBtn(
                      accent: app.reminderOn,
                      onTap: () => _toggleReminder(context),
                      child: Text(app.reminderOn ? 'On' : 'Off'),
                    ),
                    onLongPress: () => _reminderStatus(context),
                  ),
                  if (app.reminderOn)
                    row(
                      'Reminder time',
                      PawBtn(
                        accent: true,
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: t);
                          if (picked != null) app.setReminder(picked.hour * 60 + picked.minute);
                        },
                        child: Text(t.format(context)),
                      ),
                    ),
                  if (app.reminderOn)
                    ValueListenableBuilder<bool?>(
                      valueListenable: reminders.exact,
                      builder: (_, exact, __) => exact == null
                          ? const SizedBox.shrink()
                          : row(
                              'Exact timing',
                              PawBtn(
                                accent: exact,
                                onTap: exact
                                    ? null
                                    : () async {
                                        await reminders.requestExact();
                                        app.refreshReminders();
                                      },
                                child: Text(exact ? 'On' : 'Allow'),
                              ),
                            ),
                    ),
                  row('Font size', PawBtn(onTap: app.cycleFont, child: Text(app.fontLabel))),
                  row(
                    'Passcode lock',
                    PawBtn(
                      accent: app.hasPasscode,
                      onTap: () async {
                        if (app.hasPasscode) {
                          final ok = await _confirm(
                            context,
                            'Turn off passcode?',
                            'Anyone who opens the app will be able to read your diary.',
                            'Turn off',
                          );
                          if (ok) app.setPasscode(null);
                        } else {
                          final code = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(builder: (_) => const PasscodeSetupScreen()),
                          );
                          if (code != null) app.setPasscode(code);
                        }
                      },
                      child: Text(app.hasPasscode ? 'On' : 'Off'),
                    ),
                  ),
                  if (app.biometricAvailable)
                    row(
                      'Fingerprint / face',
                      PawBtn(
                        accent: app.biometricOn,
                        onTap: () => _toggleBiometric(context),
                        child: Text(app.biometricOn ? 'On' : 'Off'),
                      ),
                    ),
                  row(
                    'Export diary',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PawBtn(onTap: () => _exportPdf(context), child: const Text('PDF')),
                        const SizedBox(width: 6),
                        PawBtn(
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: app.exportText()));
                            if (context.mounted) {
                              toast(context, 'Your whole diary was copied as text.');
                            }
                          },
                          child: const Text('Text'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const _CloudCard(),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: PawBtn(onTap: () => _signOut(context), child: const Text('Sign out')),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () async {
                  final ok = await _confirm(
                    context,
                    'Delete everything?',
                    'This removes your account, entries and photos from this device. It cannot be undone.',
                    'Delete',
                  );
                  if (ok) {
                    await cloud.signOut();
                    await app.deleteEverything();
                  }
                },
                child: const Text(
                  'Delete all my data',
                  style: TextStyle(color: Color(0xFFF0607E), fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const BrandLinks(),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

/// Online sign-in status and end-to-end encrypted cloud backup.
class _CloudCard extends StatefulWidget {
  const _CloudCard();
  @override
  State<_CloudCard> createState() => _CloudCardState();
}

class _CloudCardState extends State<_CloudCard> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() job, {String? okMessage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 80)); // let the tap finish first
    final msg = await job();
    if (!mounted) return;
    setState(() => _busy = false);
    toast(context, msg ?? okMessage ?? 'Done.');
  }

  Future<void> _turnOn() async {
    final pass = await showDialog<String>(
      context: context,
      builder: (_) => const PassphraseDialog(),
    );
    if (pass == null) return;
    await _run(() async {
      final err = await cloud.enableBackup(pass);
      return err ?? 'Cloud backup is on. ${cloud.lastSyncMessage}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Pal.of(context);
        Widget head(String title, String sub) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: p.mute, fontSize: 13)),
          ],
        );

        if (!cloud.available) {
          return PawCard(
            padding: const EdgeInsets.all(16),
            child: head(
              'Online features are off',
              'Google / Apple sign-in, password reset email and encrypted cloud backup '
                  'switch on once a Firebase project is connected (README, step 5). '
                  'Everything else works offline.',
            ),
          );
        }
        final u = cloud.user;
        if (u == null) {
          return PawCard(
            padding: const EdgeInsets.all(16),
            child: head(
              'Cloud backup',
              'Sign out, then sign in with an online account (email, Google or Apple) to use backup.',
            ),
          );
        }
        return PawCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              head(
                'Cloud backup',
                app.cloudBackup
                    ? 'On for ${u.email ?? 'your account'}. Syncs automatically, encrypted on your phone first. Photos stay on this phone.'
                    : 'Signed in as ${u.email ?? 'your account'}. Back up your entries, encrypted, to restore them on a new phone.',
              ),
              const SizedBox(height: 10),
              // The buttons stay on screen the whole time (only disabled while busy), so the
              // button you tap is never removed from the tree in the middle of its own tap.
              if (!app.cloudBackup)
                PawBtn(
                  accent: true,
                  onTap: _busy ? null : _turnOn,
                  child: Text(_busy ? 'Working...' : 'Turn on backup'),
                )
              else
                Row(
                  children: [
                    PawBtn(
                      accent: true,
                      onTap: _busy ? null : () => _run(() => cloud.syncNow()),
                      child: Text(_busy ? 'Syncing...' : 'Sync now'),
                    ),
                    const SizedBox(width: 8),
                    PawBtn(
                      onTap: _busy
                          ? null
                          : () => _run(() async {
                              await cloud.disableBackup();
                              return 'Backup turned off. Copies already in the cloud stay there.';
                            }),
                      child: const Text('Turn off'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
