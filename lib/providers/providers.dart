import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/open_food_facts_service.dart';
import '../services/open_prices_service.dart';
import '../services/backup_service.dart';
import '../services/partage_service.dart';
import '../services/vocal_service.dart';
import '../services/stats_service.dart';
import '../services/export_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/recipe_import_service.dart';
import '../services/sync_service.dart';
import '../services/widget_service.dart';

// ─── SERVICES ────────────────────────────────────────────────────
final dbServiceProvider = Provider<DatabaseService>((_) => DatabaseService());
final offServiceProvider =
    Provider<OpenFoodFactsService>((_) => OpenFoodFactsService());
final openPricesServiceProvider =
    Provider<OpenPricesService>((_) => OpenPricesService());
final recipeImportServiceProvider =
    Provider<RecipeImportService>((_) => RecipeImportService());
final backupServiceProvider =
    Provider<BackupService>((ref) => BackupService(ref.read(dbServiceProvider)));
final partageServiceProvider = Provider<PartageService>((_) => PartageService());
final vocalServiceProvider = Provider<VocalService>((_) => VocalService());
final exportServiceProvider =
    Provider<ExportService>((ref) => ExportService(ref.read(dbServiceProvider)));
final statsServiceProvider =
    Provider<StatsService>((ref) => StatsService(ref.read(dbServiceProvider)));
final authServiceProvider = Provider<AuthService>((_) => AuthService());
final fcmServiceProvider = Provider<FcmService>((_) => FcmService());
final syncServiceProvider =
    Provider<SyncService>((ref) => SyncService(ref.read(dbServiceProvider)));

// La sync cloud est du "best-effort" : la donnée locale (sqlite) fait déjà
// foi et sera renvoyée au prochain uploadTout()/reconnexion si ça échoue
// maintenant. On avale donc l'erreur (réseau, permission, etc.) au lieu de
// la laisser remonter jusqu'à l'UI, qui n'a rien à faire de plus.
Future<void> _syncSilencieux(Future<void> Function() action) async {
  try {
    await action();
  } catch (e, st) {
    FirebaseCrashlytics.instance
        .recordError(e, st, reason: 'Échec de synchronisation cloud (best-effort)');
  }
}

final statsProvider = FutureProvider<StatsData>((ref) {
  ref.watch(listesNotifierProvider);
  ref.watch(articlesNotifierProvider);
  return ref.read(statsServiceProvider).calculer();
});

// ─── AUTH STATE ───────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authServiceProvider).userStream;
});

// ─── SYNC TEMPS RÉEL ─────────────────────────────────────────────
// Démarre/arrête l'écoute Firestore selon l'état de connexion, et
// invalide les providers concernés quand un changement arrive d'un
// autre appareil. À instancier une seule fois (ex: watch dans
// HomeScreen) pour qu'elle vive pendant toute la durée de l'app.
final realtimeSyncProvider = Provider<void>((ref) {
  final sync = ref.watch(syncServiceProvider);

  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    final user = next.valueOrNull;
    if (user != null) {
      sync.demarrerEcouteTempsReel(() {
        ref.invalidate(categoriesNotifierProvider);
        ref.invalidate(rayonsNotifierProvider);
        ref.invalidate(articlesNotifierProvider);
        ref.invalidate(listesNotifierProvider);
        ref.invalidate(articlesListeProvider);
        ref.invalidate(prixArticlesNotifierProvider);
      });
    } else {
      sync.arreterEcouteTempsReel();
    }
  }, fireImmediately: true);

  ref.onDispose(sync.arreterEcouteTempsReel);
});

// ─── PREFERENCES ─────────────────────────────────────────────────
final afficherStatsProvider = StateProvider<bool>((ref) => true);
final couleurThemeProvider = StateProvider<String>((ref) => 'vert');
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final afficherOnboardingProvider = StateProvider<bool>((ref) => false);
final tailleTexteProvider = StateProvider<double>((ref) => 1.0);

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
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderCategorie(c));
    ref.invalidateSelf();
  }

  Future<void> modifier(Categorie c) async {
    await ref.read(dbServiceProvider).updateCategorie(c);
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderCategorie(c));
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    await ref.read(dbServiceProvider).deleteCategorie(id);
    await _syncSilencieux(() => ref.read(syncServiceProvider).supprimerCategorie(id));
    ref.invalidateSelf();
  }

  Future<void> reordonner(List<Categorie> nouvelleListe) async {
    final db = ref.read(dbServiceProvider);
    final sync = ref.read(syncServiceProvider);
    for (int i = 0; i < nouvelleListe.length; i++) {
      final c = nouvelleListe[i].copyWith(ordre: i);
      await db.updateCategorie(c);
      await _syncSilencieux(() => sync.sauvegarderCategorie(c));
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
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderRayon(r));
    ref.invalidateSelf();
  }

  Future<void> modifier(Rayon r) async {
    await ref.read(dbServiceProvider).updateRayon(r);
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderRayon(r));
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    await ref.read(dbServiceProvider).deleteRayon(id);
    await _syncSilencieux(() => ref.read(syncServiceProvider).supprimerRayon(id));
    ref.invalidateSelf();
  }

  Future<void> reordonner(List<Rayon> nouvelleListe) async {
    final db = ref.read(dbServiceProvider);
    final sync = ref.read(syncServiceProvider);
    for (int i = 0; i < nouvelleListe.length; i++) {
      final r = nouvelleListe[i].copyWith(ordre: i);
      await db.updateRayon(r);
      await _syncSilencieux(() => sync.sauvegarderRayon(r));
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
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderArticle(a));
    ref.invalidateSelf();
  }

  Future<void> modifier(Article a) async {
    await ref.read(dbServiceProvider).updateArticle(a);
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderArticle(a));
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    await ref.read(dbServiceProvider).deleteArticle(id);
    await _syncSilencieux(() => ref.read(syncServiceProvider).supprimerArticle(id));
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
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderListe(l));
    ref.invalidateSelf();
  }

  Future<void> modifier(ListeCourses l) async {
    await ref.read(dbServiceProvider).updateListe(l);
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderListe(l));
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    // Sync d'abord : pour une liste partagée, supprimerListe a besoin de
    // retrouver son statut `partagee` en local pour savoir s'il faut la
    // supprimer ou juste quitter — donc avant que la ligne locale disparaisse.
    await _syncSilencieux(() => ref.read(syncServiceProvider).supprimerListe(id));
    await ref.read(dbServiceProvider).deleteListe(id);
    ref.invalidateSelf();
  }

  Future<ListeCourses?> dupliquer(ListeCourses source, String nom) async {
    final nouvelle =
        await ref.read(dbServiceProvider).dupliquerListe(source, nom);
    if (nouvelle != null) {
      await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderListe(nouvelle));
    }
    ref.invalidateSelf();
    return nouvelle;
  }

  // ── Collaboration ─────────────────────────────────────────────
  // Rend une liste collaborative et retourne le code à partager.
  Future<String> partager(ListeCourses liste) async {
    final items = await ref.read(dbServiceProvider).getArticlesListe(liste.id);
    final code = await ref.read(syncServiceProvider).partagerListe(liste, items);
    final misAJour = liste.copyWith(partagee: true, code: code);
    await ref.read(dbServiceProvider).updateListe(misAJour);
    ref.invalidateSelf();
    return code;
  }

  // Rejoint une liste collaborative via son code. Retourne false si le
  // code est invalide.
  Future<bool> rejoindre(String code) async {
    final resultat =
        await ref.read(syncServiceProvider).rejoindreListeParCode(code);
    if (resultat == null) return false;

    final db = ref.read(dbServiceProvider);
    await db.insertListe(resultat.liste);
    for (final item in resultat.items) {
      await db.insertArticleListe(item);
    }
    ref.invalidateSelf();
    ref.invalidate(articlesListeProvider(resultat.liste.id));
    return true;
  }

  Future<void> quitterPartage(ListeCourses liste) async {
    await ref.read(syncServiceProvider).quitterListePartagee(liste.id);
    await ref.read(dbServiceProvider).deleteListe(liste.id);
    ref.invalidateSelf();
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
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderArticleListe(al));
    ref.invalidateSelf();
    _syncWidget();
  }

  Future<void> cocher(ArticleListe al, bool valeur) async {
    final updated = al.copyWith(coche: valeur);
    await ref.read(dbServiceProvider).updateArticleListe(updated);
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderArticleListe(updated));
    ref.invalidateSelf();
    // Sync widget si c'est la liste configurée
    _syncWidget();
  }

  Future<void> _syncWidget() async {
    final widgetListeId = await WidgetService.getListeWidgetId();
    if (widgetListeId != arg) return;
    final items = await ref.read(dbServiceProvider).getArticlesListe(arg);
    // .future (pas .valueOrNull) : garantit le chargement même si aucun
    // autre écran n'a encore déclenché ces providers.
    final catalogue = await ref.read(articlesNotifierProvider.future);
    final listes = await ref.read(listesNotifierProvider.future);
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
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderArticleListe(updated));
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    final items =
        await ref.read(dbServiceProvider).getArticlesListe(arg);
    final item = items.where((i) => i.id == id).firstOrNull;
    await ref.read(dbServiceProvider).deleteArticleListe(id);
    if (item != null) {
      await _syncSilencieux(
          () => ref.read(syncServiceProvider).supprimerArticleListe(item.listeId, id));
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
      await _syncSilencieux(() => sync.sauvegarderArticleListe(item.copyWith(coche: valeur)));
    }
    ref.invalidateSelf();
  }
}

// ─── PRIX ARTICLES (budget) ───────────────────────────────────────
final prixArticlesNotifierProvider =
    AsyncNotifierProvider<PrixArticlesNotifier, List<PrixArticle>>(
        PrixArticlesNotifier.new);

class PrixArticlesNotifier extends AsyncNotifier<List<PrixArticle>> {
  @override
  Future<List<PrixArticle>> build() =>
      ref.read(dbServiceProvider).getPrixArticles();

  Future<void> definir(String articleId, double prix, {String magasin = ''}) async {
    final p = PrixArticle(articleId: articleId, prix: prix, magasin: magasin);
    final db = ref.read(dbServiceProvider);
    await db.setPrixArticle(p);
    await db.ajouterHistoriquePrix(PrixHistorique(
      id: 'hist_${DateTime.now().microsecondsSinceEpoch}',
      articleId: articleId,
      prix: prix,
      magasin: magasin,
    ));
    await _syncSilencieux(() => ref.read(syncServiceProvider).sauvegarderPrix(p));
    ref.invalidateSelf();
  }

  Future<void> supprimer(String articleId, {String magasin = ''}) async {
    await ref.read(dbServiceProvider).deletePrixArticle(articleId, magasin: magasin);
    await _syncSilencieux(
        () => ref.read(syncServiceProvider).supprimerPrix(articleId, magasin: magasin));
    ref.invalidateSelf();
  }
}

// Prix indicatif automatique : récupéré en arrière-plan depuis Open Prices
// (base communautaire Open Food Facts) pour un article qui n'a pas encore
// de prix saisi par l'utilisateur. Purement informatif — jamais enregistré
// tant que l'utilisateur n'a pas explicitement choisi de le reprendre.
// FutureProvider.family met le résultat en cache par article pour la durée
// de vie de l'app : on ne refait pas l'appel réseau à chaque rebuild.
final prixIndicatifProvider =
    FutureProvider.family<PrixTrouve?, Article>((ref, article) async {
  final dbService = ref.read(dbServiceProvider);

  // Le cache local évite de refaire une recherche réseau à chaque
  // ouverture d'écran : un résultat (trouvé ou non) reste valable 14 jours.
  final cache = await dbService.getPrixCacheWeb(article.id);
  if (cache != null) {
    final date = DateTime.tryParse(cache['date'] as String? ?? '');
    final frais = date != null &&
        DateTime.now().difference(date) < const Duration(days: 14);
    if (frais) {
      if ((cache['trouve'] as int) == 0) return null;
      return PrixTrouve(
        magasin: cache['magasin'] as String,
        prix: (cache['prix'] as num).toDouble(),
        devise: cache['devise'] as String,
        date: date,
      );
    }
  }

  final openPrices = ref.read(openPricesServiceProvider);
  PrixTrouve? resultat;

  if (article.barcode != null) {
    // Code-barres connu : produit précis, on prend le prix le moins cher.
    final resultats = await openPrices.chercherParBarcode(article.barcode!);
    resultat = resultats.firstOrNull;
  } else {
    // Article générique ("lait", "pain", "pâtes"...) : pas de produit
    // unique à interroger. Prendre le premier résultat de recherche au
    // hasard donnerait un prix pas du tout représentatif (une marque/
    // format précis parmi des dizaines). On interroge plusieurs produits
    // correspondants et on fait la moyenne de leur prix le moins cher,
    // pour une estimation plus cohérente du rayon dans son ensemble.
    final suggestions =
        await ref.read(offServiceProvider).searchByName(article.nom);
    final barcodes = suggestions
        .where((a) => a.barcode != null)
        .map((a) => a.barcode!)
        .toSet()
        .take(5)
        .toList();

    if (barcodes.isNotEmpty) {
      final resultatsParProduit = await Future.wait(
          barcodes.map((b) => openPrices.chercherParBarcode(b)));
      final prixParProduit = resultatsParProduit
          .map((r) => r.firstOrNull)
          .whereType<PrixTrouve>()
          .toList();

      if (prixParProduit.isNotEmpty) {
        final moyenne = prixParProduit.fold<double>(0, (s, p) => s + p.prix) /
            prixParProduit.length;
        resultat = PrixTrouve(
          magasin: 'Moyenne (${prixParProduit.length} produits)',
          prix: moyenne,
          devise: prixParProduit.first.devise,
          date: null,
        );
      }
    }
  }

  await dbService.setPrixCacheWeb(
    article.id,
    trouve: resultat != null,
    magasin: resultat?.magasin,
    prix: resultat?.prix,
    devise: resultat?.devise,
  );
  return resultat;
});

// Total estimé d'une liste = somme(prix unitaire × quantité) pour les
// articles ayant un prix renseigné (les autres sont ignorés du total).
// Si la liste a un magasin renseigné et qu'un prix existe pour ce
// magasin, on l'utilise ; sinon on prend le prix le moins cher connu.
final totalListeProvider =
    Provider.family<double, String>((ref, listeId) {
  final items = ref.watch(articlesListeProvider(listeId)).valueOrNull ?? [];
  final prix = ref.watch(prixArticlesNotifierProvider).valueOrNull ?? [];
  final listes = ref.watch(listesNotifierProvider).valueOrNull ?? [];
  final magasinListe = listes.where((l) => l.id == listeId).firstOrNull?.magasin;

  final prixParArticle = <String, List<PrixArticle>>{};
  for (final p in prix) {
    (prixParArticle[p.articleId] ??= []).add(p);
  }

  return items.fold<double>(0, (total, item) {
    final options = prixParArticle[item.articleId];
    if (options == null || options.isEmpty) return total;
    final correspondant = magasinListe != null
        ? options.where((p) => p.magasin == magasinListe).firstOrNull
        : null;
    final unitaire = correspondant?.prix ??
        options.map((p) => p.prix).reduce((a, b) => a < b ? a : b);
    return total + unitaire * item.quantite;
  });
});

// ─── OPEN FOOD FACTS ─────────────────────────────────────────────
final offSearchResultsProvider =
    StateProvider<List<Article>>((ref) => []);
final offSearchLoadingProvider = StateProvider<bool>((ref) => false);

// ─── RECETTES (local uniquement) ─────────────────────────────────
final recettesNotifierProvider =
    AsyncNotifierProvider<RecettesNotifier, List<Recette>>(RecettesNotifier.new);

class RecettesNotifier extends AsyncNotifier<List<Recette>> {
  @override
  Future<List<Recette>> build() => ref.read(dbServiceProvider).getRecettes();

  Future<void> ajouter(Recette r) async {
    await ref.read(dbServiceProvider).insertRecette(r);
    ref.invalidateSelf();
  }

  Future<void> modifier(Recette r) async {
    await ref.read(dbServiceProvider).insertRecette(r);
    ref.invalidateSelf();
  }

  Future<void> supprimer(String id) async {
    await ref.read(dbServiceProvider).deleteRecette(id);
    ref.invalidateSelf();
  }

  // Génère (ou complète) une liste de courses à partir d'une recette :
  // les ingrédients sans article catalogue correspondant sont créés à la
  // volée, matché par nom insensible à la casse.
  Future<void> genererListe(Recette recette, {String? listeIdExistante}) async {
    final db = ref.read(dbServiceProvider);
    String listeId;

    if (listeIdExistante != null) {
      listeId = listeIdExistante;
    } else {
      final nouvelle = ListeCourses(
        id: 'liste_${DateTime.now().millisecondsSinceEpoch}',
        nom: recette.nom,
      );
      await ref.read(listesNotifierProvider.notifier).ajouter(nouvelle);
      listeId = nouvelle.id;
    }

    // .future (pas juste .valueOrNull) : garantit que le catalogue est
    // chargé même si aucun autre écran ne l'a déjà déclenché avant.
    final catalogue = await ref.read(articlesNotifierProvider.future);
    final itemsExistants = await db.getArticlesListe(listeId);

    for (var i = 0; i < recette.ingredients.length; i++) {
      final ing = recette.ingredients[i];
      var article = catalogue
          .where((a) => a.nom.toLowerCase() == ing.nom.toLowerCase())
          .firstOrNull;

      if (article == null) {
        article = Article(
          id: 'article_${DateTime.now().millisecondsSinceEpoch}_$i',
          nom: ing.nom,
        );
        await ref.read(articlesNotifierProvider.notifier).ajouter(article);
      }

      final dejaPresent =
          itemsExistants.any((it) => it.articleId == article!.id);
      if (dejaPresent) continue;

      await ref.read(articlesListeProvider(listeId).notifier).ajouter(
            ArticleListe(
              id: 'al_${DateTime.now().millisecondsSinceEpoch}_$i',
              listeId: listeId,
              articleId: article.id,
              quantite: ing.quantite,
              unite: ing.unite,
            ),
          );
    }
  }
}
