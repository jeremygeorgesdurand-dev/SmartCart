import 'dart:convert';
import 'package:http/http.dart' as http;

// Une recette telle que trouvée sur une page web, avant tout parsing
// fin des ingrédients (fait ensuite via VocalService.nettoyer, qui sait
// déjà extraire quantité/unité/nom d'un texte libre en français).
class RecetteImportee {
  final String nom;
  final int portions;
  final List<String> ingredientsBruts;

  const RecetteImportee({
    required this.nom,
    required this.portions,
    required this.ingredientsBruts,
  });
}

// Importe une recette depuis n'importe quel site qui publie ses données
// structurées schema.org/Recipe en JSON-LD dans le <head> de la page —
// c'est le format que Google exploite pour les "rich snippets" de
// recettes, donc quasiment tous les sites de recettes grand public
// (Marmiton compris) l'utilisent déjà volontairement pour être indexés.
// On ne fait que lire cette même donnée publique, pas de scraping du
// rendu visuel de la page ni de contournement d'aucune protection.
class RecipeImportService {
  final http.Client _client;
  RecipeImportService({http.Client? client}) : _client = client ?? http.Client();

  static final _reScriptLdJson = RegExp(
    r'<script[^>]*type=["\x27]application/ld\+json["\x27][^>]*>(.*?)</script>',
    caseSensitive: false,
    dotAll: true,
  );

  Future<RecetteImportee?> importerDepuisUrl(String url) async {
    try {
      final uri = Uri.parse(url.trim());
      final response = await _client.get(
        uri,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (compatible; SmartCartApp/1.0; +import de recette)',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      for (final m in _reScriptLdJson.allMatches(response.body)) {
        final jsonText = m.group(1);
        if (jsonText == null) continue;
        try {
          final recette = _extraire(jsonDecode(jsonText));
          if (recette != null) return recette;
        } catch (_) {
          continue; // bloc JSON-LD invalide/non pertinent, on essaie le suivant
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  RecetteImportee? _extraire(dynamic node) {
    if (node is List) {
      for (final n in node) {
        final r = _extraire(n);
        if (r != null) return r;
      }
      return null;
    }
    if (node is! Map) return null;
    final map = Map<String, dynamic>.from(node);

    // Beaucoup de sites imbriquent leurs entités dans un tableau @graph.
    if (map['@graph'] != null) {
      return _extraire(map['@graph']);
    }

    final type = map['@type'];
    final estRecette =
        type == 'Recipe' || (type is List && type.contains('Recipe'));
    if (!estRecette) return null;

    final nom = (map['name'] as String?)?.trim();
    if (nom == null || nom.isEmpty) return null;

    final ingredientsRaw =
        map['recipeIngredient'] ?? map['ingredients'] ?? [];
    final ingredients = ingredientsRaw is List
        ? ingredientsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return RecetteImportee(
      nom: nom,
      portions: _extrairePortions(map['recipeYield']),
      ingredientsBruts: ingredients,
    );
  }

  int _extrairePortions(dynamic yieldVal) {
    String? texte;
    if (yieldVal is String) {
      texte = yieldVal;
    } else if (yieldVal is num) {
      return yieldVal.toInt();
    } else if (yieldVal is List && yieldVal.isNotEmpty) {
      texte = yieldVal.first.toString();
    }
    if (texte == null) return 4;
    final m = RegExp(r'\d+').firstMatch(texte);
    return m != null ? int.tryParse(m.group(0)!) ?? 4 : 4;
  }
}
