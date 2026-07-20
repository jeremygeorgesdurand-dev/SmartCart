import 'package:flutter_test/flutter_test.dart';
import 'package:smartcart/services/vocal_service.dart';

void main() {
  group('VocalService.nettoyer', () {
    test('extrait la quantité en chiffres ("3 yaourts")', () {
      final result = VocalService.nettoyer('3 yaourts');

      expect(result.quantite, 3);
      expect(result.nomArticle, 'Yaourts');
      expect(result.unite, isNull);
    });

    test('extrait la quantité en toutes lettres ("deux pommes")', () {
      final result = VocalService.nettoyer('deux pommes');

      expect(result.quantite, 2);
      expect(result.nomArticle, 'Pommes');
    });

    test('extrait l\'unité ("1 kg de pommes")', () {
      final result = VocalService.nettoyer('1 kg de pommes');

      expect(result.quantite, 1);
      expect(result.unite, 'kg');
      expect(result.nomArticle, 'Pommes');
    });

    test('supprime les mots parasites ("euh trois pommes")', () {
      final result = VocalService.nettoyer('euh trois pommes');

      expect(result.quantite, 3);
      expect(result.nomArticle, 'Pommes');
      expect(result.nomArticle.toLowerCase(), isNot(contains('euh')));
    });

    test('supprime les articles en début ("des pommes")', () {
      final result = VocalService.nettoyer('des pommes');

      expect(result.nomArticle, 'Pommes');
      expect(result.quantite, 1);
    });

    test('conserve le texte original non modifié dans texteOriginal', () {
      final result = VocalService.nettoyer('3 Yaourts');

      expect(result.texteOriginal, '3 Yaourts');
    });

    test('gère une unité en toutes lettres avec pluriel ("2 litres de lait")', () {
      final result = VocalService.nettoyer('2 litres de lait');

      expect(result.quantite, 2);
      expect(result.unite, 'L');
      expect(result.nomArticle, 'Lait');
    });

    test('supprime un autre mot parasite ("alors deux bananes")', () {
      final result = VocalService.nettoyer('alors deux bananes');

      expect(result.quantite, 2);
      expect(result.nomArticle, 'Bananes');
    });
  });

  group('VocalService.nettoyerMultiple', () {
    test('un seul article renvoie une liste à un élément', () {
      final resultats = VocalService.nettoyerMultiple('3 yaourts');

      expect(resultats, hasLength(1));
      expect(resultats.single.nomArticle, 'Yaourts');
    });

    test('découpe sur les virgules ("pommes, lait, pain")', () {
      final resultats = VocalService.nettoyerMultiple('pommes, lait, pain');

      expect(resultats, hasLength(3));
      expect(resultats.map((r) => r.nomArticle), ['Pommes', 'Lait', 'Pain']);
    });

    test('découpe sur "et" ("pommes et lait")', () {
      final resultats = VocalService.nettoyerMultiple('pommes et lait');

      expect(resultats, hasLength(2));
      expect(resultats[0].nomArticle, 'Pommes');
      expect(resultats[1].nomArticle, 'Lait');
    });

    test('combine virgules et "et" avec quantités par segment', () {
      final resultats =
          VocalService.nettoyerMultiple('deux pommes, un lait et 3 pains');

      expect(resultats, hasLength(3));
      expect(resultats[0].quantite, 2);
      expect(resultats[0].nomArticle, 'Pommes');
      expect(resultats[1].quantite, 1);
      expect(resultats[1].nomArticle, 'Lait');
      expect(resultats[2].quantite, 3);
      expect(resultats[2].nomArticle, 'Pains');
    });

    test('ignore les segments vides (virgules superflues)', () {
      final resultats = VocalService.nettoyerMultiple('pommes,, lait');

      expect(resultats, hasLength(2));
    });

    test('texte vide renvoie une liste vide', () {
      expect(VocalService.nettoyerMultiple('   '), isEmpty);
    });
  });
}
