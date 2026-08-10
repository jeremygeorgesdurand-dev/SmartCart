import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// Un ingrédient d'une recette : `texte` = ligne complète et lisible
// ("200 g de lard fumé coupé en dés"), `nom` = forme courte pour la liste
// de courses et le matching frigo ("lard fumé coupé en dés").
class IngredientRecetteDataset {
  final String texte;
  final String nom;
  const IngredientRecetteDataset({required this.texte, required this.nom});

  factory IngredientRecetteDataset.fromJson(Map<String, dynamic> j) =>
      IngredientRecetteDataset(
        texte: j['texte'] as String? ?? '',
        nom: j['nom'] as String? ?? (j['texte'] as String? ?? ''),
      );
}

class RecetteDataset {
  final String id;
  final String titre;
  final String categorie; // Plat, Dessert, Boisson, Accompagnement, Entrée
  final int portions;
  final String? image;
  final List<IngredientRecetteDataset> ingredients;
  final List<String> etapes;
  final String url;

  const RecetteDataset({
    required this.id,
    required this.titre,
    required this.categorie,
    required this.portions,
    required this.image,
    required this.ingredients,
    required this.etapes,
    required this.url,
  });

  factory RecetteDataset.fromJson(Map<String, dynamic> j) => RecetteDataset(
        id: j['id'] as String,
        titre: j['titre'] as String? ?? 'Recette',
        categorie: j['categorie'] as String? ?? 'Plat',
        portions: (j['portions'] as int?) ?? 4,
        image: j['image'] as String?,
        ingredients: (j['ingredients'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(IngredientRecetteDataset.fromJson)
            .toList(),
        etapes: (j['etapes'] as List? ?? []).map((e) => e.toString()).toList(),
        url: j['url'] as String? ?? '',
      );
}

// Charge le dataset de recettes françaises embarqué (assets/recettes_fr.json,
// extrait du Livre de cuisine de Wikilivres, CC BY-SA). Tout est local : pas
// d'API, pas de limite, fonctionne hors-ligne. Chargé une seule fois puis
// gardé en mémoire.
class RecettesDatasetService {
  // Dataset publié sur le dépôt GitHub du projet : permet d'enrichir les
  // recettes sans republier l'app (bouton "Mettre à jour" dans les réglages).
  static const _urlMaj =
      'https://raw.githubusercontent.com/jeremygeorgesdurand-dev/SmartCart/main/assets/recettes_fr.json';

  List<RecetteDataset>? _cache;
  String _attribution = 'Wikilivres — CC BY-SA';

  String get attribution => _attribution;

  Future<File> _fichierCache() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/recettes_fr_maj.json');
  }

  Future<List<RecetteDataset>> charger() async {
    if (_cache != null) return _cache!;
    // Priorité à une version téléchargée plus récente si elle existe ;
    // sinon on retombe sur l'asset embarqué (toujours disponible, hors-ligne).
    String brut;
    try {
      final f = await _fichierCache();
      brut = await f.exists()
          ? await f.readAsString()
          : await rootBundle.loadString('assets/recettes_fr.json');
    } catch (_) {
      brut = await rootBundle.loadString('assets/recettes_fr.json');
    }
    final data = jsonDecode(brut) as Map<String, dynamic>;
    final src = data['source'] as String?;
    final lic = data['licence'] as String?;
    if (src != null && lic != null) _attribution = '$src — $lic';
    _cache = (data['recettes'] as List)
        .whereType<Map<String, dynamic>>()
        .map(RecetteDataset.fromJson)
        .toList();
    return _cache!;
  }

  // Télécharge la dernière version du dataset depuis GitHub et la met en
  // cache local. Retourne le nombre de recettes. Lance en cas d'échec réseau
  // ou de fichier invalide (l'asset embarqué reste alors utilisé).
  Future<int> mettreAJour() async {
    final resp = await http
        .get(Uri.parse(_urlMaj))
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('Téléchargement impossible (code ${resp.statusCode})');
    }
    final texte = utf8.decode(resp.bodyBytes);
    final data = jsonDecode(texte);
    if (data is! Map<String, dynamic> ||
        data['recettes'] is! List ||
        (data['recettes'] as List).isEmpty) {
      throw const FormatException('Fichier de recettes invalide');
    }
    final f = await _fichierCache();
    await f.writeAsString(texte);
    _cache = null; // force un rechargement au prochain charger()
    return (data['recettes'] as List).length;
  }

  // Recherche par mots-clés (titre + ingrédients) et catégorie.
  List<RecetteDataset> rechercher(
    List<RecetteDataset> toutes, {
    String requete = '',
    String? categorie,
  }) {
    final q = _sansAccent(requete.trim().toLowerCase());
    return toutes.where((r) {
      if (categorie != null && r.categorie != categorie) return false;
      if (q.isEmpty) return true;
      if (_sansAccent(r.titre.toLowerCase()).contains(q)) return true;
      return r.ingredients
          .any((i) => _sansAccent(i.nom.toLowerCase()).contains(q));
    }).toList();
  }

  // Suggestions "frigo" : recettes qui utilisent le plus d'ingrédients
  // fournis. Renvoie chaque recette avec le nombre d'ingrédients disponibles
  // et manquants, triées par plus grand nombre de disponibles.
  List<({RecetteDataset recette, int dispo, int manquants})> parIngredients(
    List<RecetteDataset> toutes,
    List<String> ingredientsFrigo,
  ) {
    final frigo = ingredientsFrigo
        .map((e) => _sansAccent(e.trim().toLowerCase()))
        .where((e) => e.isNotEmpty)
        .toList();
    if (frigo.isEmpty) return const [];

    final resultats =
        <({RecetteDataset recette, int dispo, int manquants})>[];
    for (final r in toutes) {
      var dispo = 0;
      for (final ing in r.ingredients) {
        final nom = _sansAccent(ing.nom.toLowerCase());
        // Un ingrédient de la recette est "disponible" si l'un des
        // ingrédients du frigo apparaît dedans (ou l'inverse pour les
        // mots courts) — ex: frigo "tomate" ↔ recette "tomates pelées".
        final present = frigo.any((f) =>
            nom.contains(f) || (f.length >= 4 && f.contains(nom)));
        if (present) dispo++;
      }
      if (dispo > 0) {
        resultats.add((
          recette: r,
          dispo: dispo,
          manquants: r.ingredients.length - dispo,
        ));
      }
    }
    resultats.sort((a, b) {
      final parDispo = b.dispo.compareTo(a.dispo);
      if (parDispo != 0) return parDispo;
      return a.manquants.compareTo(b.manquants);
    });
    return resultats;
  }

  static String _sansAccent(String s) {
    const a = 'àâäéèêëïîôöùûüç';
    const b = 'aaaeeeeiioouuuc';
    var out = s;
    for (var i = 0; i < a.length; i++) {
      out = out.replaceAll(a[i], b[i]);
    }
    return out;
  }
}
