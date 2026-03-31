import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Obter o usuário atual
  User? get currentUser => _auth.currentUser;

  // Fluxo de autenticação (Stream)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login com e-mail e senha
  Future<UserCredential> signInWithEmail(String email, String password) async {
    UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Após o primeiro login bem-sucedido, podemos salvar o email para biometria
    await _storage.write(key: 'user_email', value: email);
    await _storage.write(key: 'user_password', value: password);
    return credential;
  }

  // Login com Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      // Salva o email para biometria futura (mesmo com Google)
      await _storage.write(key: 'user_email', value: userCredential.user?.email);
      return userCredential;
    } catch (e) {
      print("Erro no Google Sign-In: $e");
      return null;
    }
  }

  // Login via Biometria
  Future<UserCredential?> signInWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canAuthenticateWithBiometrics || !isDeviceSupported) return null;

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Autentique-se para entrar no app',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (didAuthenticate) {
        String? email = await _storage.read(key: 'user_email');
        String? password = await _storage.read(key: 'user_password');

        if (email != null && password != null) {
          return await _auth.signInWithEmailAndPassword(email: email, password: password);
        }
      }
      return null;
    } catch (e) {
      print("Erro na Biometria: $e");
      return null;
    }
  }

  // Cadastro com e-mail e senha
  Future<UserCredential> signUpWithEmail(String email, String password, String name) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    return credential;
  }

  // Logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
