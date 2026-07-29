// Clés des services externes utilisés par l'app.
//
// Spoonacular fournit le catalogue de recettes en ligne (recherche par
// style/régime, étapes, images, valeurs nutritionnelles, suggestion par
// ingrédients). L'inscription est gratuite et donne 150 requêtes/jour :
//   1. Va sur https://spoonacular.com/food-api  →  "Start Now" / crée un compte
//   2. Dans ton tableau de bord ("Profile" → "API Key"), copie la clé
//   3. Colle-la ci-dessous entre les guillemets, à la place du texte témoin
//
// Tant que la clé n'est pas renseignée, l'app reste pleinement utilisable :
// les écrans de recettes en ligne affichent juste un message invitant à la
// configurer (voir ApiConfig.spoonacularConfigure).
class ApiConfig {
  static const String spoonacularKey = 'COLLE_TA_CLE_SPOONACULAR_ICI';

  static bool get spoonacularConfigure =>
      spoonacularKey.isNotEmpty &&
      spoonacularKey != 'COLLE_TA_CLE_SPOONACULAR_ICI';
}
