import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/spoonacular_service.dart';
import '../services/traduction_service.dart';

final spoonacularServiceProvider =
    Provider<SpoonacularService>((_) => SpoonacularService());

final traductionServiceProvider =
    Provider<TraductionService>((_) => TraductionService());

// ── Filtres de l'écran d'exploration ────────────────────────────
class FiltresRecettes {
  final String requete;
  final String? type; // "main course", "dessert", "breakfast", "salad"...
  final String? regime; // "vegetarian", "vegan", "gluten free"
  final bool proteine;

  const FiltresRecettes({
    this.requete = '',
    this.type,
    this.regime,
    this.proteine = false,
  });

  FiltresRecettes copyWith({
    String? requete,
    Object? type = _absent,
    Object? regime = _absent,
    bool? proteine,
  }) =>
      FiltresRecettes(
        requete: requete ?? this.requete,
        type: type == _absent ? this.type : type as String?,
        regime: regime == _absent ? this.regime : regime as String?,
        proteine: proteine ?? this.proteine,
      );

  static const _absent = Object();
}

final filtresRecettesProvider =
    StateProvider<FiltresRecettes>((_) => const FiltresRecettes());

// Résultats d'exploration : recherche Spoonacular puis traduction des
// titres en français (en une requête groupée).
final rechercheRecettesProvider =
    FutureProvider.autoDispose<List<RecetteEnLigneResume>>((ref) async {
  final filtres = ref.watch(filtresRecettesProvider);
  final service = ref.read(spoonacularServiceProvider);
  final resultats = await service.rechercher(
    requete: filtres.requete,
    type: filtres.type,
    regime: filtres.regime,
    proteine: filtres.proteine,
  );
  return _traduireTitres(ref, resultats);
});

// Détail traduit : titre, étapes et noms d'ingrédients passés en français.
final detailRecetteProvider = FutureProvider.autoDispose
    .family<RecetteEnLigne, int>((ref, id) async {
  final service = ref.read(spoonacularServiceProvider);
  final trad = ref.read(traductionServiceProvider);
  final r = await service.details(id);

  // Un seul lot de textes à traduire (titre + étapes + noms d'ingrédients)
  // pour économiser le quota, puis on redistribue.
  final textes = <String>[
    r.titre,
    ...r.etapes,
    ...r.ingredients.map((i) => i.nom),
  ];
  final traduits = await trad.traduirePlusieurs(textes);

  var k = 0;
  final titre = traduits[k++];
  final etapes = [for (var i = 0; i < r.etapes.length; i++) traduits[k++]];
  final ingredients = [
    for (final ing in r.ingredients)
      IngredientEnLigne(
          nom: traduits[k++], quantite: ing.quantite, unite: ing.unite),
  ];

  return RecetteEnLigne(
    id: r.id,
    titre: titre,
    image: r.image,
    tempsMinutes: r.tempsMinutes,
    portions: r.portions,
    ingredients: ingredients,
    etapes: etapes,
    calories: r.calories,
    proteines: r.proteines,
    vegetarien: r.vegetarien,
    sansGluten: r.sansGluten,
  );
});

// ── Frigo : ingrédients saisis → suggestions ────────────────────
final frigoIngredientsProvider = StateProvider<List<String>>((_) => []);

final suggestionsFrigoProvider =
    FutureProvider.autoDispose<List<RecetteEnLigneResume>>((ref) async {
  final ingredients = ref.watch(frigoIngredientsProvider);
  if (ingredients.isEmpty) return const [];
  final service = ref.read(spoonacularServiceProvider);
  final trad = ref.read(traductionServiceProvider);

  // Les noms d'ingrédients sont saisis en français : Spoonacular attend de
  // l'anglais, on traduit donc dans l'autre sens avant la requête.
  final enAnglais =
      await trad.traduirePlusieurs(ingredients, de: 'fr', vers: 'en');
  final resultats = await service.parIngredients(enAnglais);
  return _traduireTitres(ref, resultats);
});

Future<List<RecetteEnLigneResume>> _traduireTitres(
    Ref ref, List<RecetteEnLigneResume> resultats) async {
  if (resultats.isEmpty) return resultats;
  final trad = ref.read(traductionServiceProvider);
  final titres = await trad.traduirePlusieurs(resultats.map((r) => r.titre).toList());
  return [
    for (var i = 0; i < resultats.length; i++)
      RecetteEnLigneResume(
        id: resultats[i].id,
        titre: titres[i],
        image: resultats[i].image,
        tempsMinutes: resultats[i].tempsMinutes,
        portions: resultats[i].portions,
        ingredientsUtilises: resultats[i].ingredientsUtilises,
        ingredientsManquants: resultats[i].ingredientsManquants,
      ),
  ];
}
