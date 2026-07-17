import '../models/models.dart';
import 'database_service.dart';

class StatsData {
  final int totalArticles;
  final int totalListes;
  final int totalListesArchivees;
  final double tauxCompletionMoyen;
  final List<({Article article, int count})> topArticles;
  final List<({Categorie categorie, int count})> topCategories;
  final List<({Rayon rayon, int count})> topRayons;
  final List<Article> articlesSansListe;
  final int articlesAchetesCeMois;

  const StatsData({
    required this.totalArticles,
    required this.totalListes,
    required this.totalListesArchivees,
    required this.tauxCompletionMoyen,
    required this.topArticles,
    required this.topCategories,
    required this.topRayons,
    required this.articlesSansListe,
    required this.articlesAchetesCeMois,
  });
}

class StatsService {
  final DatabaseService _db;
  StatsService(this._db);

  Future<StatsData> calculer() async {
    final articles = await _db.getArticles();
    final categories = await _db.getCategories();
    final rayons = await _db.getRayons();
    final listes = await _db.getListes(inclureArchivees: true);
    final listesActives = listes.where((l) => !l.archivee).toList();
    final listesArchivees = listes.where((l) => l.archivee).toList();

    final List<ArticleListe> tousItems = [];
    for (final liste in listes) {
      tousItems.addAll(await _db.getArticlesListe(liste.id));
    }

    // Taux de completion moyen
    double tauxMoyen = 0;
    if (listes.isNotEmpty) {
      double total = 0;
      int listesAvecItems = 0;
      for (final liste in listes) {
        final items = tousItems.where((i) => i.listeId == liste.id).toList();
        if (items.isNotEmpty) {
          total += items.where((i) => i.coche).length / items.length;
          listesAvecItems++;
        }
      }
      tauxMoyen = listesAvecItems > 0 ? (total / listesAvecItems) * 100 : 0;
    }

    // Top articles
    final Map<String, int> compteurArticles = {};
    for (final item in tousItems) {
      compteurArticles[item.articleId] = (compteurArticles[item.articleId] ?? 0) + 1;
    }
    final topArticles = compteurArticles.entries
        .map((e) {
          final a = articles.where((a) => a.id == e.key).firstOrNull;
          return a != null ? (article: a, count: e.value) : null;
        })
        .whereType<({Article article, int count})>()
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Top categories
    final Map<String, int> compteurCat = {};
    for (final item in tousItems) {
      final a = articles.where((a) => a.id == item.articleId).firstOrNull;
      if (a?.categorieId != null) {
        compteurCat[a!.categorieId!] = (compteurCat[a.categorieId!] ?? 0) + 1;
      }
    }
    final topCategories = compteurCat.entries
        .map((e) {
          final c = categories.where((c) => c.id == e.key).firstOrNull;
          return c != null ? (categorie: c, count: e.value) : null;
        })
        .whereType<({Categorie categorie, int count})>()
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Top rayons
    final Map<String, int> compteurRayon = {};
    for (final item in tousItems) {
      final a = articles.where((a) => a.id == item.articleId).firstOrNull;
      if (a?.rayonId != null) {
        compteurRayon[a!.rayonId!] = (compteurRayon[a.rayonId!] ?? 0) + 1;
      }
    }
    final topRayons = compteurRayon.entries
        .map((e) {
          final r = rayons.where((r) => r.id == e.key).firstOrNull;
          return r != null ? (rayon: r, count: e.value) : null;
        })
        .whereType<({Rayon rayon, int count})>()
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Articles jamais utilises
    final utilisesIds = tousItems.map((i) => i.articleId).toSet();
    final articlesSansListe = articles.where((a) => !utilisesIds.contains(a.id)).toList();

    // Articles ce mois
    final debutMois = DateTime(DateTime.now().year, DateTime.now().month, 1);
    int articlesAchetesCeMois = 0;
    for (final liste in listes) {
      if (liste.createdAt.isAfter(debutMois)) {
        articlesAchetesCeMois += tousItems.where((i) => i.listeId == liste.id).length;
      }
    }

    return StatsData(
      totalArticles: articles.length,
      totalListes: listesActives.length,
      totalListesArchivees: listesArchivees.length,
      tauxCompletionMoyen: tauxMoyen,
      topArticles: topArticles.take(10).toList(),
      topCategories: topCategories.take(6).toList(),
      topRayons: topRayons.take(6).toList(),
      articlesSansListe: articlesSansListe.take(10).toList(),
      articlesAchetesCeMois: articlesAchetesCeMois,
    );
  }
}
