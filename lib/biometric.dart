import 'package:local_auth/local_auth.dart';

/// Fingerprint / face unlock through the system prompt.
class Biometric {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True if this phone has biometrics set up that we can use.
  static Future<bool> available() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      return false;
    }
  }
}
