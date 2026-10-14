import 'package:google_sign_in/google_sign_in.dart';
import '../../app_info.dart';

/// Login com Google no aparelho (Credential Manager do Android): devolve o idToken para a API
/// do WaxClub conferir, ou `null` se o usuário cancelou.
class GoogleAuth {
  static bool _initialized = false;

  static Future<String?> signIn() async {
    final google = GoogleSignIn.instance;
    if (!_initialized) {
      await google.initialize(serverClientId: kGoogleServerClientId);
      _initialized = true;
    }
    try {
      final account = await google.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Ao sair da conta WaxClub: a próxima entrada com Google volta a mostrar a escolha de conta.
  static Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
