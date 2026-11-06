import 'package:flutter/material.dart';

import 'cloud.dart';
import 'lock.dart';
import 'mochi.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Sign in / Create account. Accounts live on this device only.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startOnCreate = false});
  final bool startOnCreate;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _create = widget.startOnCreate;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _stay = true;
  bool _protect = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  int get _strength {
    final s = _pass.text;
    var n = 0;
    if (s.length >= 8) n++;
    if (RegExp(r'[a-z]').hasMatch(s) && RegExp(r'[A-Z]').hasMatch(s)) n++;
    if (RegExp(r'\d').hasMatch(s)) n++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(s) && s.length >= 8) n++;
    return n;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final pass = _pass.text;
    if (_create) {
      if (_name.text.trim().isEmpty) {
        setState(() => _error = 'Please tell Mochi your name.');
        return;
      }
      if (!email.contains('@') || !email.contains('.')) {
        setState(() => _error = 'That email does not look right.');
        return;
      }
      if (pass.length < 8) {
        setState(() => _error = 'Use at least 8 characters.');
        return;
      }
      setState(() {
        _error = null;
        _busy = true;
      });
      if (cloud.available) {
        final err = await cloud.signUp(_name.text, email, pass);
        if (err != null) {
          if (mounted) {
            setState(() {
              _error = err;
              _busy = false;
            });
          }
          return;
        }
      }
      String? code;
      if (_protect) {
        code = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const PasscodeSetupScreen()),
        );
      }
      await app.createAccount(_name.text, email, pass, passcode: code);
    } else {
      if (app.hasAccount && app.signIn(email, pass, stay: _stay)) return;
      // Not matching this device: try the online account (also covers a new phone
      // and a password that was changed through "Forgot password").
      if (cloud.available) {
        setState(() {
          _error = null;
          _busy = true;
        });
        final err = await cloud.signInEmail(email, pass);
        if (err != null) {
          if (mounted) setState(() => _error = err);
        } else {
          await _finishCloudSignIn(pass);
        }
      } else {
        setState(() => _error = 'Email or password did not match this device.');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// A cloud sign-in succeeded: create or reuse the on-device diary for that person.
  Future<void> _finishCloudSignIn(String? password) async {
    final u = cloud.user;
    if (u == null) return;
    final email = (u.email ?? _email.text).trim().toLowerCase();
    // On an empty phone with a backup waiting in the cloud, offer to restore it.
    app.offerRestore = app.entries.isEmpty && !app.cloudBackup && await cloud.hasBackup();
    if (!app.hasAccount) {
      final name = (u.displayName ?? '').trim().isNotEmpty
          ? u.displayName!.trim()
          : email.split('@').first;
      await app.createAccount(
        name,
        email,
        password ?? 'cloud-${DateTime.now().microsecondsSinceEpoch}',
        stay: _stay,
      );
    } else if (app.userEmail == email) {
      if (password != null) await app.updateLocalPassword(password);
      app.signInTrusted(stay: _stay);
    } else {
      // A different account's diary is still on this phone.
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final p = Pal.of(ctx);
          return AlertDialog(
            backgroundColor: p.card,
            surfaceTintColor: Colors.transparent,
            title: const Text('Another diary is on this phone'),
            content: Text(
              'The diary for ${app.userEmail} is still stored here. To sign in as $email it has to be '
              'removed from this phone first. If it is not backed up online, it will be lost.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove and continue'),
              ),
            ],
          );
        },
      );
      if (replace == true) {
        await app.deleteEverything();
        app.offerRestore = await cloud.hasBackup();
        final name = (u.displayName ?? '').trim().isNotEmpty
            ? u.displayName!.trim()
            : email.split('@').first;
        await app.createAccount(
          name,
          email,
          password ?? 'cloud-${DateTime.now().microsecondsSinceEpoch}',
          stay: _stay,
        );
      } else {
        await cloud.signOut();
      }
    }
  }

  Future<void> _social(bool apple) async {
    FocusScope.of(context).unfocus();
    if (!cloud.available) {
      toast(
        context,
        'Online sign-in is not set up yet. Connect a Firebase project (see README), '
        'then Google and Apple sign-in will work.',
      );
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = apple ? await cloud.signInApple() : await cloud.signInGoogle();
    if (err != null) {
      if (mounted) setState(() => _error = err);
    } else {
      await _finishCloudSignIn(null);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _forgot() async {
    if (!cloud.available) {
      toast(
        context,
        'Password reset email needs an online account. Connect Firebase (see README). '
        'On this phone you can also use "Forgot passcode?" on the lock screen.',
      );
      return;
    }
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Type your email above first, then tap Forgot password.');
      return;
    }
    final err = await cloud.resetPassword(email);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      toast(context, 'Reset email sent. Check your inbox.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final labelStyle = const TextStyle(fontWeight: FontWeight.w700, fontSize: 14);
    final strength = _strength;
    const strengthLabels = ['', 'Weak', 'Getting there', 'Good', 'Strong'];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _create
                        ? const Mochi(face: 'wink', size: 96)
                        : Mochi(mood: app.mascotMood, size: 110),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _create ? 'Create your diary' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _create ? 'A cosy, private place to write' : 'Mochi saved your spot',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.mute, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (_create) ...[
                    Text('Your name', style: labelStyle),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: pawInput(p, "Mochi's friend"),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text('Email', style: labelStyle),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: pawInput(p, 'you@example.com'),
                  ),
                  const SizedBox(height: 14),
                  Text('Password', style: labelStyle),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    decoration: pawInput(p, _create ? 'At least 8 characters' : 'Your password'),
                  ),
                  if (_create) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Expanded(
                            child: Container(
                              height: 5,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: i < strength ? p.acc : p.line,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          strengthLabels[strength],
                          style: TextStyle(color: p.mute, fontSize: 13),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: p.acc,
                      checkColor: Pal.onAcc,
                      value: _protect,
                      onChanged: (v) => setState(() => _protect = v ?? false),
                      title: Text(
                        'Protect my diary with a passcode',
                        style: TextStyle(fontSize: 13, color: p.mute),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: p.acc,
                            checkColor: Pal.onAcc,
                            value: _stay,
                            onChanged: (v) => setState(() => _stay = v ?? true),
                            title: Text(
                              'Stay signed in',
                              style: TextStyle(fontSize: 13, color: p.mute),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _forgot,
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: p.ink,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFF0607E), fontSize: 13),
                      ),
                    ),
                  SizedBox(
                    height: 52,
                    child: PawBtn(
                      accent: true,
                      radius: 16,
                      onTap: _busy ? null : _submit,
                      child: Text(
                        _create ? 'Create account' : 'Sign in',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  ...[
                    const SizedBox(height: 14),
                    Text(
                      _create ? 'or sign up with' : 'or continue with',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.mute, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final n in ['Apple', 'Google']) ...[
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: PawBtn(
                                onTap: _busy ? null : () => _social(n == 'Apple'),
                                child: Text(n),
                              ),
                            ),
                          ),
                          if (n == 'Apple') const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_create ? 'Already have an account? ' : 'New here? '),
                      InkWell(
                        onTap: app.hasAccount || cloud.available || !_create
                            ? () => setState(() {
                                _create = !_create;
                                _error = null;
                              })
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            _create ? 'Sign in' : 'Create account',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_create && app.hasAccount)
                    Text(
                      'Accounts are stored on this device only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.mute, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
