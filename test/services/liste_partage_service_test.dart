import 'package:flutter_test/flutter_test.dart';
import 'package:smartcart/services/liste_partage_service.dart';

void main() {
  group('ListePartageService.parserTexte', () {
    test('parse un format valide complet avec Nom, Magasin et articles', () {
      const texte = '''
=== SMARTCART LISTE ===
Nom: Ma liste
Magasin: Carrefour
---
Pain;×1;Boulangerie;Rayon Pain
Lait;×2L;Frigo;Produits frais
=== FIN SMARTCART ===
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNotNull);
      expect(result!.nomListe, 'Ma liste');
      expect(result.magasin, 'Carrefour');
      expect(result.articles, hasLength(2));

      final pain = result.articles[0];
      expect(pain.nom, 'Pain');
      expect(pain.quantite, 1);
      expect(pain.unite, isNull);
      expect(pain.categorieNom, 'Boulangerie');
      expect(pain.rayonNom, 'Rayon Pain');

      final lait = result.articles[1];
      expect(lait.nom, 'Lait');
      expect(lait.quantite, 2);
      expect(lait.unite, 'L');
      expect(lait.categorieNom, 'Frigo');
      expect(lait.rayonNom, 'Produits frais');
    });

    test('retourne null quand l\'en-tête est absent', () {
      const texte = '''
Nom: Ma liste
---
Pain;×1;Boulangerie;Rayon Pain
=== FIN SMARTCART ===
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNull);
    });

    test('retourne null quand il n\'y a aucun article', () {
      const texte = '''
=== SMARTCART LISTE ===
Nom: Ma liste
Magasin: Carrefour
---
=== FIN SMARTCART ===
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNull);
    });

    test('retourne null quand il n\'y a pas de séparateur --- (donc pas de corps)', () {
      const texte = '''
=== SMARTCART LISTE ===
Nom: Ma liste
Pain;×1;Boulangerie;Rayon Pain
=== FIN SMARTCART ===
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNull);
    });

    test('parse la quantité sans unité (×2)', () {
      const texte = '''
=== SMARTCART LISTE ===
---
Pomme;×2
=== FIN SMARTCART ===
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNotNull);
      final pomme = result!.articles.single;
      expect(pomme.quantite, 2);
      expect(pomme.unite, isNull);
    });

    test('parse la quantité avec unité accolée (×2L)', () {
      const texte = '''
=== SMARTCART LISTE ===
---
Lait;×2L
=== FIN SMARTCART ===
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNotNull);
      final lait = result!.articles.single;
      expect(lait.quantite, 2);
      expect(lait.unite, 'L');
    });

    test('gère les lignes avec champs manquants (juste nom;×1)', () {
      const texte = '''
=== SMARTCART LISTE ===
---
Beurre;×1
=== FIN SMARTCART ===
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNotNull);
      final beurre = result!.articles.single;
      expect(beurre.nom, 'Beurre');
      expect(beurre.quantite, 1);
      expect(beurre.unite, isNull);
      expect(beurre.categorieNom, '');
      expect(beurre.rayonNom, '');
    });

    test('utilise le nom par défaut quand la ligne Nom: est absente', () {
      const texte = '''
=== SMARTCART LISTE ===
---
Pain;×1
=== FIN SMARTCART ===
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNotNull);
      expect(result!.nomListe, 'Liste importée');
      expect(result.magasin, isNull);
    });

    test('ignore les lignes vides et les lignes sans nom dans le corps', () {
      const texte = '''
=== SMARTCART LISTE ===
---

;×1
Pain;×1
=== FIN SMARTCART ===
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNotNull);
      expect(result!.articles, hasLength(1));
      expect(result.articles.single.nom, 'Pain');
    });

    test('arrête le parsing à la ligne de fin', () {
      const texte = '''
=== SMARTCART LISTE ===
---
Pain;×1
=== FIN SMARTCART ===
Sel;×1
''';

      final result = ListePartageService.parserTexte(texte);

      expect(result, isNotNull);
      expect(result!.articles, hasLength(1));
      expect(result.articles.single.nom, 'Pain');
    });
  });
}
