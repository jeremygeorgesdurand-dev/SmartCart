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

// Indicateur de succès ("liste terminée") : une version plus saturée/foncée
// du primary du thème, PAS colorScheme.tertiary. tertiary tourne la teinte
// choisie d'environ 120° sur la roue Material (un thème "brun" donnait un
// indicateur rouge/orange, "gris ardoise" un bleu) — alors que primary
// conserve toujours la teinte exacte choisie par l'utilisateur. On accentue
// juste un peu la saturation/luminosité pour que "terminé" reste visible-
// ment distinct de l'état "en cours" (qui utilise le primary tel quel).
Color couleurSucces(BuildContext context) {
  final hsl = HSLColor.fromColor(Theme.of(context).colorScheme.primary);
  return hsl
      .withSaturation((hsl.saturation + 0.2).clamp(0.0, 1.0))
      .withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0))
      .toColor();
}

// Garde la teinte choisie librement dans le sélecteur de couleur
// personnalisée, mais impose une saturation/luminosité minimales : sans ça,
// une couleur pâle (facile à tomber dessus par erreur sur une roue HSV, ex.
// en tapant près du centre/du bord clair) donne un thème entier "délavé"
// une fois passée dans ColorScheme.fromSeed, contrairement aux 16 couleurs
// prédéfinies qui sont toutes volontairement saturées/foncées.
Color couleurSeedUtilisable(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.45, 1.0))
      .withLightness(hsl.lightness.clamp(0.20, 0.45))
      .toColor();
}

// Texte noir ou blanc selon le fond donné, pour garantir un texte lisible
// sur une couleur choisie librement par l'utilisateur (personnalisation) —
// un fond sombre (ex. thème "noir"/gris foncé) veut du texte blanc, un fond
// clair veut du texte sombre, et ça ne peut pas être deviné à l'avance.
Color texteContrastant(Color fond) =>
    ThemeData.estimateBrightnessForColor(fond) == Brightness.dark
        ? Colors.white
        : Colors.black87;
