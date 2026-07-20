import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream de l'état de connexion
  Stream<User?> get userStream => _auth.authStateChanges();

  // Utilisateur actuel
  User? get currentUser => _auth.currentUser;
  bool get isConnected => _auth.currentUser != null;

  // Connexion Google
  Future<User?> connecterGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // annulé

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      throw Exception('Erreur connexion Google : $e');
    }
  }

  // Déconnexion
  Future<void> deconnecter() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Supprime le compte Firebase Auth. Firebase exige une connexion
  // récente pour cette opération sensible : si besoin, redemande une
  // authentification Google avant de réessayer.
  Future<void> supprimerCompte() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Reconnexion annulée');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      await user.delete();
    }
    await _googleSignIn.signOut();
  }
}
