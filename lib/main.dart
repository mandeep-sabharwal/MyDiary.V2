import 'package:flutter/material.dart';

import 'auth.dart';
import 'biometric.dart';
import 'cloud.dart';
import 'home.dart';
import 'lock.dart';
import 'mochi.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw something immediately; the slow startup work happens behind this screen.
  runApp(const _Boot());
}

/// Shows a loading screen while the app opens its storage, so a slow or stuck step
/// can never leave the screen blank.
class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool _ready = false;
  String? _error;
  String _step = 'Opening your diary...';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final sw = Stopwatch()..start();
    try {
      debugPrint('[STARTUP] app.init()');
      await app.init().timeout(const Duration(seconds: 25));
      debugPrint('[STARTUP] app.init() done ${sw.elapsed}');
    } catch (e, st) {
      debugPrint('[STARTUP] app.init() FAILED: $e\n$st');
      if (mounted) setState(() => _error = '$e');
      return;
    }

    if (mounted) setState(() => _step = 'Checking online features...');
    try {
      // Quietly stays off until Firebase is connected (flutterfire configure).
      await cloud.init().timeout(const Duration(seconds: 10));
      debugPrint('[STARTUP] cloud.init() done: available=${cloud.available} ${sw.elapsed}');
      if (!cloud.available) debugPrint('[STARTUP] cloud off: ${cloud.initError}');
    } catch (e) {
      debugPrint('[STARTUP] cloud.init() skipped: $e');
    }

    try {
      app.biometricAvailable = await Biometric.available().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[STARTUP] biometrics skipped: $e');
    }

    debugPrint('[STARTUP] ready ${sw.elapsed}');
    if (!mounted) return;
    setState(() => _ready = true);
    app.refreshReminders();
    cloud.autoSync(); // live + startup sync when cloud backup is on
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const PawsieApp();
    if (_error != null) return _StartupError(_error!);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF6F0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Mochi(mood: Mood.sleepy, size: 96),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: Color(0xFFF59BB0)),
              const SizedBox(height: 16),
              Text(_step, style: const TextStyle(color: Color(0xFF6E5F73))),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  'Pawsie Diary could not start.\n\n'
                  'It keeps your diary encrypted with a key held in the Android Keystore. '
                  'Try restarting the emulator or phone. If it keeps happening, use an '
                  'emulator image with Google Play, or a real phone. This can also happen if the '
                  'app data was restored from a backup onto a different phone: the key never '
                  'leaves the original phone.\n\n$message',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PawsieApp extends StatefulWidget {
  const PawsieApp({super.key});
  @override
  State<PawsieApp> createState() => _PawsieAppState();
}

class _PawsieAppState extends State<PawsieApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      app.refreshReminders();
      cloud.autoSync();
    }
    if (state == AppLifecycleState.paused && app.hasPasscode && !app.suppressLock) {
      // Close anything pushed on top, then show the lock screen.
      navKey.currentState?.popUntil((r) => r.isFirst);
      app.lockIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'Pawsie Diary',
        debugShowCheckedModeBanner: false,
        navigatorKey: navKey,
        themeMode: app.themeMode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(app.fontScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.hasAccount) return AuthScreen(startOnCreate: !cloud.available);
        if (!app.signedIn) return const AuthScreen();
        if (app.locked) return const LockScreen();
        return const HomeShell();
      },
    );
  }
}
