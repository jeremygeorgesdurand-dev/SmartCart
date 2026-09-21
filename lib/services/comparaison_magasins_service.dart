import '../models/models.dart';

// Total estimé d'une liste de courses pour UN magasin donné.
class ComparaisonMagasin {
  final String magasin;
  final double total;
  // Noms des articles de la liste sans prix connu pour ce magasin (ni prix
  // spécifique, ni prix générique de repli) — le total les ignore, donc on
  // les affiche pour que l'utilisateur sache que la comparaison est partielle.
  final List<String> articlesManquants;

  const ComparaisonMagasin({
    required this.magasin,
    required this.total,
    required this.articlesManquants,
  });
}

// Compare le coût d'une liste de courses selon les différents magasins pour
// lesquels on connaît au moins un prix (issus de saisies manuelles ou de
// tickets de caisse scannés). Pur et synchrone : facilement testable sans
// Riverpod ni base de données.
class ComparaisonMagasinsService {
  static List<ComparaisonMagasin> calculer({
    required List<ArticleListe> items,
    required List<Article> catalogue,
    required List<PrixArticle> prix,
  }) {
    // Quantité totale par article (regroupe d'éventuelles lignes en double).
    final quantiteParArticle = <String, int>{};
    for (final item in items) {
      quantiteParArticle[item.articleId] =
          (quantiteParArticle[item.articleId] ?? 0) + item.quantite;
    }
    if (quantiteParArticle.isEmpty) return const [];

    // Prix par (articleId, magasin), et prix génériques (sans magasin
    // précisé) utilisés en repli quand aucun prix spécifique n'existe.
    final prixSpecifique = <String, Map<String, double>>{};
    final prixGenerique = <String, double>{};
    for (final p in prix) {
      if (p.magasin.isEmpty) {
        prixGenerique[p.articleId] = p.prix;
      } else {
        (prixSpecifique[p.articleId] ??= {})[p.magasin] = p.prix;
      }
    }

    // Magasins candidats : ceux ayant au moins un prix spécifique pour un
    // article de cette liste (un prix générique seul ne définit pas un
    // magasin à comparer).
    final magasins = <String>{};
    for (final articleId in quantiteParArticle.keys) {
      magasins.addAll(prixSpecifique[articleId]?.keys ?? const []);
    }

    String nomArticle(String id) =>
        catalogue.where((a) => a.id == id).firstOrNull?.nom ?? 'Article';

    final resultats = <ComparaisonMagasin>[];
    for (final magasin in magasins) {
      var total = 0.0;
      final manquants = <String>[];
      for (final entry in quantiteParArticle.entries) {
        final prixArticleMagasin =
            prixSpecifique[entry.key]?[magasin] ?? prixGenerique[entry.key];
        if (prixArticleMagasin == null) {
          manquants.add(nomArticle(entry.key));
          continue;
        }
        total += prixArticleMagasin * entry.value;
      }
      resultats.add(ComparaisonMagasin(
        magasin: magasin,
        total: total,
        articlesManquants: manquants,
      ));
    }
    resultats.sort((a, b) => a.total.compareTo(b.total));
    return resultats;
  }
}
