import '../models/models.dart';
import 'database_service.dart';

/// Suggestion de réachat basée sur la fréquence d'achat historique
/// d'un article (intervalle moyen entre les listes où il apparaît).
class SuggestionReassort {
  final Article article;
  final int joursRetard;
  final double intervalleMoyenJours;
  final DateTime derniereFois;

  const SuggestionReassort({
    required this.article,
    required this.joursRetard,
    required this.intervalleMoyenJours,
    required this.derniereFois,
  });
}

class SuggestionsService {
  final DatabaseService _db;
  SuggestionsService(this._db);

  // Bornes de l'intervalle moyen considéré comme fiable : en dessous,
  // trop de bruit (courses ponctuelles rapprochées) ; au-dessus, achat
  // trop rare pour être un vrai cycle de réassort.
  static const int _intervalleMinJours = 2;
  static const int _intervalleMaxJours = 60;
  static const int _limite = 10;

  Future<List<SuggestionReassort>> calculer() async {
    final articles = await _db.getArticles();
    final listes = await _db.getListes(inclureArchivees: true);

    // Pour chaque article, l'ensemble des listes distinctes où il apparaît.
    final Map<String, Set<String>> listesParArticle = {};
    for (final liste in listes) {
      final items = await _db.getArticlesListe(liste.id);
      for (final item in items) {
        (listesParArticle[item.articleId] ??= {}).add(liste.id);
      }
    }

    final maintenant = DateTime.now();
    final suggestions = <SuggestionReassort>[];

    for (final entry in listesParArticle.entries) {
      if (entry.value.length < 2) continue;
      final article = articles.where((a) => a.id == entry.key).firstOrNull;
      if (article == null) continue;

      final dates = listes
          .where((l) => entry.value.contains(l.id))
          .map((l) => l.createdAt)
          .toList()
        ..sort();

      final intervalles = <int>[];
      for (int i = 1; i < dates.length; i++) {
        intervalles.add(dates[i].difference(dates[i - 1]).inDays);
      }
      if (intervalles.isEmpty) continue;

      final intervalleMoyen =
          intervalles.reduce((a, b) => a + b) / intervalles.length;
      if (intervalleMoyen < _intervalleMinJours ||
          intervalleMoyen > _intervalleMaxJours) {
        continue;
      }

      final derniereFois = dates.last;
      final joursDepuis = maintenant.difference(derniereFois).inDays;
      if (joursDepuis < intervalleMoyen) continue;

      suggestions.add(SuggestionReassort(
        article: article,
        joursRetard: (joursDepuis - intervalleMoyen).round(),
        intervalleMoyenJours: intervalleMoyen,
        derniereFois: derniereFois,
      ));
    }

    suggestions.sort((a, b) => b.joursRetard.compareTo(a.joursRetard));
    return suggestions.take(_limite).toList();
  }
}
