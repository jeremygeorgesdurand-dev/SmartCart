import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// Une recette telle que listée dans une grille de résultats (données
// légères : de quoi afficher une vignette et ouvrir le détail).
class RecetteEnLigneResume {
  final int id;
  final String titre;
  final String? image;
  final int? tempsMinutes;
  final int? portions;
  // Pour la recherche "à partir du frigo" : combien d'ingrédients tapés
  // sont utilisés, et combien manquent.
  final int? ingredientsUtilises;
  final int? ingredientsManquants;

  const RecetteEnLigneResume({
    required this.id,
    required this.titre,
    this.image,
    this.tempsMinutes,
    this.portions,
    this.ingredientsUtilises,
    this.ingredientsManquants,
  });

  factory RecetteEnLigneResume.fromJson(Map<String, dynamic> j) =>
      RecetteEnLigneResume(
        id: j['id'] as int,
        titre: (j['title'] as String?) ?? 'Recette',
        image: j['image'] as String?,
        tempsMinutes: j['readyInMinutes'] as int?,
        portions: j['servings'] as int?,
        ingredientsUtilises: (j['usedIngredientCount'] as int?),
        ingredientsManquants: (j['missedIngredientCount'] as int?),
      );
}

class IngredientEnLigne {
  final String nom;
  final double quantite;
  final String? unite;
  const IngredientEnLigne(
      {required this.nom, required this.quantite, this.unite});

  factory IngredientEnLigne.fromJson(Map<String, dynamic> j) =>
      IngredientEnLigne(
        nom: (j['nameClean'] as String?) ?? (j['name'] as String?) ?? '',
        quantite: (j['amount'] as num?)?.toDouble() ?? 1,
        unite: (j['unit'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['unit'] as String).trim(),
      );
}

// Détail complet d'une recette (étapes, ingrédients, nutrition).
class RecetteEnLigne {
  final int id;
  final String titre;
  final String? image;
  final int? tempsMinutes;
  final int portions;
  final List<IngredientEnLigne> ingredients;
  final List<String> etapes;
  final int? calories; // kcal par portion
  final int? proteines; // g par portion
  final bool? vegetarien;
  final bool? sansGluten;

  const RecetteEnLigne({
    required this.id,
    required this.titre,
    this.image,
    this.tempsMinutes,
    required this.portions,
    required this.ingredients,
    required this.etapes,
    this.calories,
    this.proteines,
    this.vegetarien,
    this.sansGluten,
  });

  factory RecetteEnLigne.fromJson(Map<String, dynamic> j) {
    final ingredients = (j['extendedIngredients'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(IngredientEnLigne.fromJson)
        .where((i) => i.nom.isNotEmpty)
        .toList();

    // analyzedInstructions : [{ steps: [{ number, step }] }] — on aplatit
    // en une simple liste de phrases d'étapes.
    final etapes = <String>[];
    for (final bloc in (j['analyzedInstructions'] as List? ?? [])) {
      if (bloc is Map<String, dynamic>) {
        for (final s in (bloc['steps'] as List? ?? [])) {
          if (s is Map<String, dynamic>) {
            final phrase = (s['step'] as String?)?.trim();
            if (phrase != null && phrase.isNotEmpty) etapes.add(phrase);
          }
        }
      }
    }

    int? nutriment(String nom) {
      final liste = (j['nutrition']?['nutrients'] as List? ?? []);
      for (final n in liste) {
        if (n is Map<String, dynamic> && n['name'] == nom) {
          return (n['amount'] as num?)?.round();
        }
      }
      return null;
    }

    return RecetteEnLigne(
      id: j['id'] as int,
      titre: (j['title'] as String?) ?? 'Recette',
      image: j['image'] as String?,
      tempsMinutes: j['readyInMinutes'] as int?,
      portions: (j['servings'] as int?) ?? 4,
      ingredients: ingredients,
      etapes: etapes,
      calories: nutriment('Calories'),
      proteines: nutriment('Protein'),
      vegetarien: j['vegetarian'] as bool?,
      sansGluten: j['glutenFree'] as bool?,
    );
  }
}

// Levée quand la clé API n'est pas renseignée : l'UI l'attrape pour
// afficher un message de configuration plutôt qu'une erreur réseau.
class SpoonacularNonConfigure implements Exception {
  const SpoonacularNonConfigure();
}

class SpoonacularService {
  final http.Client _client;
  SpoonacularService({http.Client? client})
      : _client = client ?? http.Client();

  static const _hote = 'api.spoonacular.com';

  Map<String, String> _params(Map<String, String> extra) {
    if (!ApiConfig.spoonacularConfigure) {
      throw const SpoonacularNonConfigure();
    }
    return {'apiKey': ApiConfig.spoonacularKey, ...extra};
  }

  // Recherche par mots-clés + filtres. type: "main course", "dessert",
  // "breakfast"... ; diet: "high protein"* n'existe pas côté diet, mais on
  // gère "protéiné" via minProtein. diet accepte "vegetarian", "vegan",
  // "gluten free", "ketogenic".
  Future<List<RecetteEnLigneResume>> rechercher({
    String? requete,
    String? type,
    String? regime,
    bool proteine = false,
    int nombre = 20,
  }) async {
    final params = <String, String>{
      'number': '$nombre',
      'addRecipeInformation': 'true',
      'sort': 'popularity',
      if (requete != null && requete.trim().isNotEmpty) 'query': requete.trim(),
      if (type != null) 'type': type,
      if (regime != null) 'diet': regime,
      // "protéiné" : au moins 20 g de protéines par portion.
      if (proteine) 'minProtein': '20',
    };
    final uri = Uri.https(_hote, '/recipes/complexSearch', _params(params));
    final reponse =
        await _client.get(uri).timeout(const Duration(seconds: 12));
    _verifier(reponse);
    final data = jsonDecode(reponse.body) as Map<String, dynamic>;
    return (data['results'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RecetteEnLigneResume.fromJson)
        .toList();
  }

  Future<RecetteEnLigne> details(int id) async {
    final uri = Uri.https(_hote, '/recipes/$id/information',
        _params({'includeNutrition': 'true'}));
    final reponse =
        await _client.get(uri).timeout(const Duration(seconds: 12));
    _verifier(reponse);
    return RecetteEnLigne.fromJson(
        jsonDecode(reponse.body) as Map<String, dynamic>);
  }

  // Suggestions à partir d'ingrédients (le "frigo") : classées par nombre
  // d'ingrédients manquants croissant (ranking=1).
  Future<List<RecetteEnLigneResume>> parIngredients(
      List<String> ingredients,
      {int nombre = 20}) async {
    final uri = Uri.https(_hote, '/recipes/findByIngredients', _params({
      'ingredients': ingredients.map((e) => e.trim()).join(','),
      'number': '$nombre',
      'ranking': '1',
      'ignorePantry': 'true',
    }));
    final reponse =
        await _client.get(uri).timeout(const Duration(seconds: 12));
    _verifier(reponse);
    final data = jsonDecode(reponse.body) as List;
    return data
        .whereType<Map<String, dynamic>>()
        .map(RecetteEnLigneResume.fromJson)
        .toList();
  }

  void _verifier(http.Response reponse) {
    if (reponse.statusCode == 200) return;
    if (reponse.statusCode == 401 || reponse.statusCode == 403) {
      throw Exception('Clé Spoonacular invalide ou refusée');
    }
    if (reponse.statusCode == 402) {
      throw Exception(
          'Quota quotidien Spoonacular atteint (150 requêtes/jour en gratuit)');
    }
    throw Exception('Erreur Spoonacular (${reponse.statusCode})');
  }
}
