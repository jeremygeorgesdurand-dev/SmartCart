import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

// Message lisible à partir d'une erreur réseau/Firebase, plutôt que
// d'afficher tel quel un `Exception: ...`/`FirebaseException` technique à
// des utilisateurs non techniques (voir PRODUCT.md).
String messageErreurLisible(Object e, String contexte) {
  if (e is SocketException ||
      (e is FirebaseException &&
          (e.code == 'unavailable' || e.code == 'network-request-failed'))) {
    return 'Pas de connexion internet. Réessaie plus tard.';
  }
  if (e is FirebaseException && e.code == 'permission-denied') {
    return '$contexte : accès refusé. Vérifie que tu es bien connecté et '
        'membre de cette liste.';
  }
  if (e is FirebaseException) {
    return '$contexte : ${e.message ?? e.code}';
  }
  return '$contexte : $e';
}
