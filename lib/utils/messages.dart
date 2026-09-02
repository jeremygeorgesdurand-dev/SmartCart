import 'package:flutter/material.dart';

// Affiche un petit message (toast) en bas de l'écran, COURT et NON EMPILÉ :
// on masque d'abord le message en cours (`clearSnackBars`) pour ne pas laisser
// une file de messages s'accumuler et rester à l'écran bien plus longtemps que
// « quelques secondes ». Durée volontairement brève (~2 s).
void afficherMessage(
  BuildContext context,
  String texte, {
  Color? couleur,
  SnackBarAction? action,
  Duration duree = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(texte),
      backgroundColor: couleur,
      action: action,
      duration: duree,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    ));
}
