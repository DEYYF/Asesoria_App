import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Autentícate para acceder a tu asesoría',
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: 'user_email', value: email);
    await _storage.write(key: 'user_password', value: password);
    await _storage.write(key: 'use_biometrics', value: 'true');
  }

  Future<Map<String, String>?> getCredentials() async {
    final email = await _storage.read(key: 'user_email');
    final password = await _storage.read(key: 'user_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  Future<bool> hasStoredCredentials() async {
    final useBiometrics = await _storage.read(key: 'use_biometrics');
    return useBiometrics == 'true';
  }

  Future<void> clearCredentials() async {
    await _storage.deleteAll();
  }
}
