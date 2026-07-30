import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recettes_dataset_service.dart';

final recettesDatasetServiceProvider =
    Provider<RecettesDatasetService>((_) => RecettesDatasetService());

// Charge (une fois) le dataset de recettes françaises embarqué.
final toutesRecettesProvider =
    FutureProvider<List<RecetteDataset>>((ref) async {
  return ref.read(recettesDatasetServiceProvider).charger();
});

// ── Filtres de l'écran Explorer ─────────────────────────────────
class FiltresRecettes {
  final String requete;
  final String? categorie; // Plat, Dessert, Boisson, Accompagnement, Entrée

  const FiltresRecettes({this.requete = '', this.categorie});

  FiltresRecettes copyWith({String? requete, Object? categorie = _absent}) =>
      FiltresRecettes(
        requete: requete ?? this.requete,
        categorie:
            categorie == _absent ? this.categorie : categorie as String?,
      );

  static const _absent = Object();
}

final filtresRecettesProvider =
    StateProvider<FiltresRecettes>((_) => const FiltresRecettes());

// Résultats filtrés de l'écran Explorer.
final rechercheRecettesProvider =
    FutureProvider<List<RecetteDataset>>((ref) async {
  final filtres = ref.watch(filtresRecettesProvider);
  final service = ref.read(recettesDatasetServiceProvider);
  final toutes = await ref.watch(toutesRecettesProvider.future);
  return service.rechercher(toutes,
      requete: filtres.requete, categorie: filtres.categorie);
});

// Détail d'une recette (déjà en mémoire, retrouvée par id).
final detailRecetteProvider =
    FutureProvider.family<RecetteDataset?, String>((ref, id) async {
  final toutes = await ref.watch(toutesRecettesProvider.future);
  return toutes.where((r) => r.id == id).firstOrNull;
});

// ── Frigo : ingrédients saisis → suggestions ────────────────────
final frigoIngredientsProvider = StateProvider<List<String>>((_) => []);

enum FrigoTri { plusUtilises, moinsAAcheter }

final frigoTriProvider = StateProvider<FrigoTri>((_) => FrigoTri.plusUtilises);

typedef SuggestionFrigo = ({RecetteDataset recette, int dispo, int manquants});

final suggestionsFrigoProvider =
    FutureProvider<List<SuggestionFrigo>>((ref) async {
  final ingredients = ref.watch(frigoIngredientsProvider);
  if (ingredients.isEmpty) return const [];
  final service = ref.read(recettesDatasetServiceProvider);
  final toutes = await ref.watch(toutesRecettesProvider.future);
  return service.parIngredients(toutes, ingredients);
});
