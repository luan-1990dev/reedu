import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInWithEmail(String email, String password) async {
    try {
      debugPrint("Tentando login com e-mail: $email");
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      debugPrint("Login bem-sucedido!");
      
      await _storage.write(key: 'user_email', value: email);
      await _storage.write(key: 'user_password', value: password);
    } on FirebaseAuthException catch (e) {
      debugPrint("ERRO FIREBASE AUTH: Código=[${e.code}] Mensagem=[${e.message}]");
      throw _handleAuthError(e);
    } catch (e) {
      debugPrint("ERRO DESCONHECIDO NO LOGIN: $e");
      throw 'Erro inesperado ao tentar logar.';
    }
  }

  Future<void> signUpWithEmail(String email, String password, String name) async {
    try {
      debugPrint("Tentando cadastrar: $email");
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      debugPrint("Cadastro realizado com sucesso!");
    } on FirebaseAuthException catch (e) {
      debugPrint("ERRO FIREBASE SIGNUP: Código=[${e.code}] Mensagem=[${e.message}]");
      throw _handleAuthError(e);
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'E-mail não encontrado. Crie uma conta primeiro.';
      case 'wrong-password':
        return 'Senha incorreta. Tente novamente.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado. Tente fazer login.';
      case 'invalid-email':
        return 'O formato do e-mail é inválido.';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres.';
      case 'user-disabled':
        return 'Este usuário foi desativado.';
      case 'operation-not-allowed':
        return 'O login com e-mail e senha não está ativado no Firebase Console.';
      case 'invalid-credential':
        // Este erro acontece muito quando a conta foi criada via Google
        return 'Credenciais inválidas. Se você criou a conta com o Google, use o botão Entrar com Google.';
      default:
        return 'Erro de autenticação (${e.code}): ${e.message}';
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint("Iniciando Google Sign-In...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("Usuário cancelou o login do Google.");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      debugPrint("Login com Google bem-sucedido: ${userCredential.user?.email}");
      
      await _storage.write(key: 'user_email', value: userCredential.user?.email);
      return userCredential;
    } catch (e) {
      debugPrint("ERRO NO GOOGLE SIGN-IN: $e");
      return null;
    }
  }

  Future<UserCredential?> signInWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      if (!canAuthenticateWithBiometrics) return null;

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
      debugPrint("Erro na Biometria: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
