import 'package:flutter_test/flutter_test.dart';
import 'package:smartcart/services/export_service.dart';

void main() {
  group('ExportService.parseLigne', () {
    test('retourne null pour une ligne vide', () {
      expect(ExportService.parseLigne(''), isNull);
      expect(ExportService.parseLigne('   '), isNull);
    });

    test('retourne null pour un commentaire', () {
      expect(ExportService.parseLigne('# ceci est un commentaire'), isNull);
      expect(ExportService.parseLigne('#Pain'), isNull);
    });

    test('parse une ligne simple avec juste un nom', () {
      final result = ExportService.parseLigne('Pain');

      expect(result, isNotNull);
      expect(result!.nom, 'Pain');
      expect(result.categorieNom, '');
      expect(result.rayonNom, '');
    });

    test('parse une ligne complète nom;categorie;rayon', () {
      final result = ExportService.parseLigne('Pain;Placards;Épicerie');

      expect(result, isNotNull);
      expect(result!.nom, 'Pain');
      expect(result.categorieNom, 'Placards');
      expect(result.rayonNom, 'Épicerie');
    });

    test('nettoie le préfixe tiret', () {
      final result = ExportService.parseLigne('- Pain');

      expect(result, isNotNull);
      expect(result!.nom, 'Pain');
    });

    test('nettoie le préfixe puce', () {
      final result = ExportService.parseLigne('• Pain');

      expect(result, isNotNull);
      expect(result!.nom, 'Pain');
    });

    test('nettoie le préfixe numéroté', () {
      final result = ExportService.parseLigne('1. Pain');

      expect(result, isNotNull);
      expect(result!.nom, 'Pain');
    });

    test('nettoie un préfixe numéroté avec parenthèse', () {
      final result = ExportService.parseLigne('2) Lait');

      expect(result, isNotNull);
      expect(result!.nom, 'Lait');
    });

    test('nettoie un préfixe combiné puis parse les champs', () {
      final result = ExportService.parseLigne('- Pain;Placards;Épicerie');

      expect(result, isNotNull);
      expect(result!.nom, 'Pain');
      expect(result.categorieNom, 'Placards');
      expect(result.rayonNom, 'Épicerie');
    });

    test('retourne null si le nom est vide après nettoyage', () {
      expect(ExportService.parseLigne('- '), isNull);
      expect(ExportService.parseLigne(';Placards;Épicerie'), isNull);
    });
  });
}
