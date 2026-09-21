// Teste ComparaisonMagasinsService.calculer : le coût estimé d'une liste
// selon les magasins pour lesquels on connaît des prix.
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcart/models/models.dart';
import 'package:smartcart/services/comparaison_magasins_service.dart';

void main() {
  final catalogue = [
    Article(id: 'lait', nom: 'Lait'),
    Article(id: 'pain', nom: 'Pain'),
    Article(id: 'beurre', nom: 'Beurre'),
  ];

  group('calculer', () {
    test('liste vide : aucune comparaison', () {
      final resultats = ComparaisonMagasinsService.calculer(
        items: [],
        catalogue: catalogue,
        prix: [],
      );
      expect(resultats, isEmpty);
    });

    test('aucun prix spécifique par magasin : aucune comparaison possible',
        () {
      final items = [
        ArticleListe(id: 'al1', listeId: 'l', articleId: 'lait', quantite: 1),
      ];
      // Un prix générique seul ne définit pas un magasin à comparer.
      final prix = [PrixArticle(articleId: 'lait', prix: 1.5, magasin: '')];

      final resultats = ComparaisonMagasinsService.calculer(
          items: items, catalogue: catalogue, prix: prix);
      expect(resultats, isEmpty);
    });

    test('deux magasins avec tous les prix connus : totaux corrects, triés',
        () {
      final items = [
        ArticleListe(id: 'al1', listeId: 'l', articleId: 'lait', quantite: 2),
        ArticleListe(id: 'al2', listeId: 'l', articleId: 'pain', quantite: 1),
      ];
      final prix = [
        PrixArticle(articleId: 'lait', prix: 1.0, magasin: 'Lidl'),
        PrixArticle(articleId: 'pain', prix: 1.2, magasin: 'Lidl'),
        PrixArticle(articleId: 'lait', prix: 1.3, magasin: 'Carrefour'),
        PrixArticle(articleId: 'pain', prix: 0.9, magasin: 'Carrefour'),
      ];

      final resultats = ComparaisonMagasinsService.calculer(
          items: items, catalogue: catalogue, prix: prix);

      expect(resultats, hasLength(2));
      // Lidl : 2×1.0 + 1×1.2 = 3.2 ; Carrefour : 2×1.3 + 1×0.9 = 3.5
      expect(resultats[0].magasin, 'Lidl');
      expect(resultats[0].total, closeTo(3.2, 0.001));
      expect(resultats[1].magasin, 'Carrefour');
      expect(resultats[1].total, closeTo(3.5, 0.001));
      expect(resultats[0].articlesManquants, isEmpty);
      expect(resultats[1].articlesManquants, isEmpty);
    });

    test('prix générique utilisé en repli quand le magasin n\'a pas de prix '
        'spécifique pour un article', () {
      final items = [
        ArticleListe(id: 'al1', listeId: 'l', articleId: 'lait', quantite: 1),
        ArticleListe(id: 'al2', listeId: 'l', articleId: 'pain', quantite: 1),
      ];
      final prix = [
        // Lidl n'a qu'un prix pour le lait ; le pain retombe sur le générique.
        PrixArticle(articleId: 'lait', prix: 1.0, magasin: 'Lidl'),
        PrixArticle(articleId: 'pain', prix: 0.8, magasin: ''),
      ];

      final resultats = ComparaisonMagasinsService.calculer(
          items: items, catalogue: catalogue, prix: prix);

      expect(resultats, hasLength(1));
      expect(resultats.single.total, closeTo(1.8, 0.001));
      expect(resultats.single.articlesManquants, isEmpty);
    });

    test('article sans aucun prix pour un magasin : exclu du total et '
        'signalé dans les manquants', () {
      final items = [
        ArticleListe(id: 'al1', listeId: 'l', articleId: 'lait', quantite: 1),
        ArticleListe(id: 'al2', listeId: 'l', articleId: 'beurre', quantite: 1),
      ];
      final prix = [
        PrixArticle(articleId: 'lait', prix: 1.0, magasin: 'Lidl'),
        // Aucun prix (spécifique ou générique) pour le beurre.
      ];

      final resultats = ComparaisonMagasinsService.calculer(
          items: items, catalogue: catalogue, prix: prix);

      expect(resultats, hasLength(1));
      expect(resultats.single.total, closeTo(1.0, 0.001));
      expect(resultats.single.articlesManquants, ['Beurre']);
    });

    test('lignes en double pour le même article : quantités additionnées',
        () {
      final items = [
        ArticleListe(id: 'al1', listeId: 'l', articleId: 'lait', quantite: 1),
        ArticleListe(id: 'al2', listeId: 'l', articleId: 'lait', quantite: 2),
      ];
      final prix = [
        PrixArticle(articleId: 'lait', prix: 1.0, magasin: 'Lidl'),
      ];

      final resultats = ComparaisonMagasinsService.calculer(
          items: items, catalogue: catalogue, prix: prix);

      expect(resultats.single.total, closeTo(3.0, 0.001)); // (1+2) × 1.0
    });
  });
}
