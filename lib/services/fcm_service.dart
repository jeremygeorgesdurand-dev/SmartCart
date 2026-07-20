import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Demande la permission de notification et retourne le token de
  /// l'appareil, ou null si refusé/indisponible.
  Future<String?> demanderPermissionEtObtenirToken() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return _messaging.getToken();
  }

  Future<String?> get tokenActuel => _messaging.getToken();
}
