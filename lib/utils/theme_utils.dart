import 'package:flutter/material.dart';

// Rouge et jaune fixes pour les actions destructrices ("Supprimer") et
// d'avertissement ("Vider la liste"). Les rôles Material 3 error/tertiary
// suivent la couleur de thème choisie par l'utilisateur : le rôle "error" en
// particulier est pensé pour du texte lisible sur fond sombre (donc pâle en
// mode sombre), pas pour une action qui doit sauter aux yeux — et les deux
// actions doivent rester nettement distinctes l'une de l'autre quel que
// soit le thème.
Color couleurDanger(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFEF5350)
        : const Color(0xFFC62828);

Color couleurAvertissement(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFCA28)
        : const Color(0xFFF9A825);

// Vert fixe pour les indicateurs de succès ("liste terminée"). colorScheme
// .tertiary tourne la teinte du thème choisi (~120° sur la roue Material) :
// pour un thème "brun" ça donne un rouge/orange, pour "gris ardoise" un
// bleu — un indicateur de succès ne doit jamais changer de sens selon le
// thème.
Color couleurSucces(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF66BB6A)
        : const Color(0xFF2E7D32);
