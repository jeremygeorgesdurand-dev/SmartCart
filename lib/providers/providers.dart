import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/open_food_facts_service.dart';
import '../services/partage_service.dart';
import '../services/vocal_service.dart';
import '../services/stats_service.dart';
import '../services/export_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/widget_service.dart';

// ─── SERVICES ────────────────────────────────────────────────────
final dbServiceProvider = Provider<DatabaseService>((_) => DatabaseService());
final offServiceProvider =
    Provider<OpenFoodFactsService>((_) => OpenFoodFactsService());
final partageServiceProvider = Provider<PartageService>((_) => PartageService());
final vocalServiceProvider = Provider<VocalService>((_) => VocalService());
final exportServiceProvider =
    Provider<ExportService>((ref) => ExportService(ref.read(dbServiceProvider)));
final statsServiceProvider =
    Provider<StatsService>((ref) => StatsService(ref.read(dbServiceProvider)));
final authServiceProvider = Provider<AuthService>((_) => AuthService());
final syncServiceProvider =
    Provider<SyncService>((ref) => SyncService(ref.read(dbServiceProvider)));

final statsProvider = FutureProvider<StatsData>((ref) {
  ref.watch(listesNotifierProvider);
  ref.watch(articlesNotifierProvider);
  return ref.read(statsServiceProvider).calculer();
});

// ─── AUTH STATE ───────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authServiceProvider).userStream;
});

// ─── PREFERENCES ─────────────────────────────────────────────────
final afficherStatsProvider = StateProvider<bool>((ref) => true);
final couleurThemeProvider = StateProvider<String>((ref) => 'vert');

// ─── TRI ET FILTRES ──────────────────────────────────────────────
enum SortMode { alphabetique, categorie, rayon }

final sortModeProvider =
    StateProvider<SortMode>((ref) => SortMode.alphabetique);
final filterCategorieProvider = StateProvider<String?>((ref) => null);
final filterRayonProvider = StateProvider<String?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

// ─── SÉLECTION CATALOGUE ─────────────────────────────────────────
final listeSelectionneeProvider = StateProvider<ListeCourses?>((ref) => null);
final articlesSelectionnesProvider =
    StateProvider<Set<String>>((ref) => {});

// ─── CATÉGORIES ──────────────────────────────────────────────────
final categoriesProvider = FutureProvider<List<Categorie>>(
    (ref) async => ref.read(dbServiceProvider).getCategories());

final categoriesNotifierProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Categorie>>(
        CategoriesNotifier.new);

class CategoriesNotifier extends AsyncNotifier<List<Categorie>> {
  @override
  Future<List<Categorie>> build() =>
      ref.read(dbServiceProvider).getCategories();

  Future<void> ajouter(Categorie c) async {
    await ref.read(dbServiceProvider).insertCategorie(c);
    await ref.read(syncServiceProvider).sauvegarderCategorie(c);
    ref.invalidateSelf();
  }

  Future<void> modifier(Categorie c) async {
    await ref.read(dbServiceProvider).updateCategorie(c);
    await ref.read(syncServiceProvider).sauvegarderCategorie(c);
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    await ref.read(dbServiceProvider).deleteCategorie(id);
    await ref.read(syncServiceProvider).supprimerCategorie(id);
    ref.invalidateSelf();
  }

  Future<void> reordonner(List<Categorie> nouvelleListe) async {
    final db = ref.read(dbServiceProvider);
    final sync = ref.read(syncServiceProvider);
    for (int i = 0; i < nouvelleListe.length; i++) {
      final c = nouvelleListe[i].copyWith(ordre: i);
      await db.updateCategorie(c);
      await sync.sauvegarderCategorie(c);
    }
    ref.invalidateSelf();
  }
}

// ─── RAYONS ──────────────────────────────────────────────────────
final rayonsNotifierProvider =
    AsyncNotifierProvider<RayonsNotifier, List<Rayon>>(RayonsNotifier.new);

class RayonsNotifier extends AsyncNotifier<List<Rayon>> {
  @override
  Future<List<Rayon>> build() => ref.read(dbServiceProvider).getRayons();

  Future<void> ajouter(Rayon r) async {
    await ref.read(dbServiceProvider).insertRayon(r);
    await ref.read(syncServiceProvider).sauvegarderRayon(r);
    ref.invalidateSelf();
  }

  Future<void> modifier(Rayon r) async {
    await ref.read(dbServiceProvider).updateRayon(r);
    await ref.read(syncServiceProvider).sauvegarderRayon(r);
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    await ref.read(dbServiceProvider).deleteRayon(id);
    await ref.read(syncServiceProvider).supprimerRayon(id);
    ref.invalidateSelf();
  }

  Future<void> reordonner(List<Rayon> nouvelleListe) async {
    final db = ref.read(dbServiceProvider);
    final sync = ref.read(syncServiceProvider);
    for (int i = 0; i < nouvelleListe.length; i++) {
      final r = nouvelleListe[i].copyWith(ordre: i);
      await db.updateRayon(r);
      await sync.sauvegarderRayon(r);
    }
    ref.invalidateSelf();
  }
}

// ─── ARTICLES ────────────────────────────────────────────────────
final articlesNotifierProvider =
    AsyncNotifierProvider<ArticlesNotifier, List<Article>>(
        ArticlesNotifier.new);

class ArticlesNotifier extends AsyncNotifier<List<Article>> {
  @override
  Future<List<Article>> build() => ref.read(dbServiceProvider).getArticles();

  Future<void> ajouter(Article a) async {
    await ref.read(dbServiceProvider).insertArticle(a);
    await ref.read(syncServiceProvider).sauvegarderArticle(a);
    ref.invalidateSelf();
  }

  Future<void> modifier(Article a) async {
    await ref.read(dbServiceProvider).updateArticle(a);
    await ref.read(syncServiceProvider).sauvegarderArticle(a);
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    await ref.read(dbServiceProvider).deleteArticle(id);
    await ref.read(syncServiceProvider).supprimerArticle(id);
    ref.invalidateSelf();
  }
}

final articlesFiltresProvider =
    Provider<AsyncValue<List<Article>>>((ref) {
  final articlesAsync = ref.watch(articlesNotifierProvider);
  final sort = ref.watch(sortModeProvider);
  final filterCat = ref.watch(filterCategorieProvider);
  final filterRay = ref.watch(filterRayonProvider);
  final query = ref.watch(searchQueryProvider);

  return articlesAsync.whenData((articles) {
    var liste = articles.where((a) {
      final matchQuery = query.isEmpty ||
          a.nom.toLowerCase().contains(query.toLowerCase());
      final matchCat = filterCat == null || a.categorieId == filterCat;
      final matchRay = filterRay == null || a.rayonId == filterRay;
      return matchQuery && matchCat && matchRay;
    }).toList();

    switch (sort) {
      case SortMode.alphabetique:
        liste.sort((a, b) {
          if (filterCat != null) {
            final aM = a.categorieId == filterCat ? 0 : 1;
            final bM = b.categorieId == filterCat ? 0 : 1;
            if (aM != bM) return aM.compareTo(bM);
          }
          if (filterRay != null) {
            final aM = a.rayonId == filterRay ? 0 : 1;
            final bM = b.rayonId == filterRay ? 0 : 1;
            if (aM != bM) return aM.compareTo(bM);
          }
          return a.nom.compareTo(b.nom);
        });
      case SortMode.categorie:
        liste.sort((a, b) =>
            (a.categorieId ?? '').compareTo(b.categorieId ?? ''));
      case SortMode.rayon:
        liste.sort(
            (a, b) => (a.rayonId ?? '').compareTo(b.rayonId ?? ''));
    }
    return liste;
  });
});

// ─── LISTES ───────────────────────────────────────────────────────
final listesNotifierProvider =
    AsyncNotifierProvider<ListesNotifier, List<ListeCourses>>(
        ListesNotifier.new);

class ListesNotifier extends AsyncNotifier<List<ListeCourses>> {
  @override
  Future<List<ListeCourses>> build() =>
      ref.read(dbServiceProvider).getListes();

  Future<void> ajouter(ListeCourses l) async {
    await ref.read(dbServiceProvider).insertListe(l);
    await ref.read(syncServiceProvider).sauvegarderListe(l);
    ref.invalidateSelf();
  }

  Future<void> modifier(ListeCourses l) async {
    await ref.read(dbServiceProvider).updateListe(l);
    await ref.read(syncServiceProvider).sauvegarderListe(l);
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    await ref.read(dbServiceProvider).deleteListe(id);
    await ref.read(syncServiceProvider).supprimerListe(id);
    ref.invalidateSelf();
  }

  Future<ListeCourses?> dupliquer(ListeCourses source, String nom) async {
    final nouvelle =
        await ref.read(dbServiceProvider).dupliquerListe(source, nom);
    if (nouvelle != null) {
      await ref.read(syncServiceProvider).sauvegarderListe(nouvelle);
    }
    ref.invalidateSelf();
    return nouvelle;
  }
}

// ─── ARTICLES D'UNE LISTE ────────────────────────────────────────
final articleListeSortProvider =
    StateProvider<SortMode>((ref) => SortMode.rayon);

final articlesListeProvider = AsyncNotifierProviderFamily<
    ArticlesListeNotifier,
    List<ArticleListe>,
    String>(ArticlesListeNotifier.new);

class ArticlesListeNotifier
    extends FamilyAsyncNotifier<List<ArticleListe>, String> {
  @override
  Future<List<ArticleListe>> build(String listeId) =>
      ref.read(dbServiceProvider).getArticlesListe(listeId);

  Future<void> ajouter(ArticleListe al) async {
    await ref.read(dbServiceProvider).insertArticleListe(al);
    await ref.read(syncServiceProvider).sauvegarderArticleListe(al);
    ref.invalidateSelf();
    _syncWidget();
  }

  Future<void> cocher(ArticleListe al, bool valeur) async {
    final updated = al.copyWith(coche: valeur);
    await ref.read(dbServiceProvider).updateArticleListe(updated);
    await ref.read(syncServiceProvider).sauvegarderArticleListe(updated);
    ref.invalidateSelf();
    // Sync widget si c'est la liste configurée
    _syncWidget();
  }

  Future<void> _syncWidget() async {
    final widgetListeId = await WidgetService.getListeWidgetId();
    if (widgetListeId != arg) return;
    final items = await ref.read(dbServiceProvider).getArticlesListe(arg);
    final catalogue = ref.read(articlesNotifierProvider).valueOrNull ?? [];
    final listes = ref.read(listesNotifierProvider).valueOrNull ?? [];
    final liste = listes.where((l) => l.id == arg).firstOrNull;
    if (liste == null) return;
    await WidgetService.mettreAJourWidget(
      liste: liste,
      items: items,
      catalogue: catalogue,
    );
  }

  Future<void> modifierQuantite(ArticleListe al, int quantite) async {
    final updated = al.copyWith(quantite: quantite);
    await ref.read(dbServiceProvider).updateArticleListe(updated);
    await ref.read(syncServiceProvider).sauvegarderArticleListe(updated);
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    final items =
        await ref.read(dbServiceProvider).getArticlesListe(arg);
    final item = items.where((i) => i.id == id).firstOrNull;
    await ref.read(dbServiceProvider).deleteArticleListe(id);
    if (item != null) {
      await ref
          .read(syncServiceProvider)
          .supprimerArticleListe(item.listeId, id);
    }
    ref.invalidateSelf();
  }

  Future<void> cocherTous(bool valeur) async {
    await ref.read(dbServiceProvider).cocherTous(arg, valeur);
    // Sync tous les items
    final items =
        await ref.read(dbServiceProvider).getArticlesListe(arg);
    final sync = ref.read(syncServiceProvider);
    for (final item in items) {
      await sync.sauvegarderArticleListe(item.copyWith(coche: valeur));
    }
    ref.invalidateSelf();
  }
}

// ─── OPEN FOOD FACTS ─────────────────────────────────────────────
final offSearchResultsProvider =
    StateProvider<List<Article>>((ref) => []);
final offSearchLoadingProvider = StateProvider<bool>((ref) => false);
