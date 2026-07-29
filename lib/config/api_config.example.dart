// MODÈLE de configuration des clés API — copie ce fichier en
// `api_config.dart` (dans le même dossier) et colle ta clé dedans.
// Le vrai `api_config.dart` est ignoré par Git (voir .gitignore) pour que
// ta clé ne parte jamais sur GitHub.
//
// Spoonacular fournit le catalogue de recettes en ligne (recherche par
// style/régime, étapes, images, valeurs nutritionnelles, suggestion par
// ingrédients). L'inscription est gratuite et donne 150 requêtes/jour :
//   1. Va sur https://spoonacular.com/food-api  →  crée un compte
//   2. Dans ton tableau de bord ("Profile" → "API Key"), copie la clé
//   3. Colle-la ci-dessous entre les guillemets, à la place du texte témoin
class ApiConfig {
  static const String spoonacularKey = 'COLLE_TA_CLE_SPOONACULAR_ICI';

  static bool get spoonacularConfigure =>
      spoonacularKey.isNotEmpty &&
      spoonacularKey != 'COLLE_TA_CLE_SPOONACULAR_ICI';
}
