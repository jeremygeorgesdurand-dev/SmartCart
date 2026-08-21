import 'package:flutter_test/flutter_test.dart';
import 'package:smartcart/models/models.dart';
import 'package:smartcart/services/doublons_service.dart';

void main() {
  Article art(String nom) => Article(id: nom, nom: nom);

  group('trouverProche', () {
    final catalogue = [art('Blanc de poulet'), art('Lait demi-écrémé'), art('Pâtes')];

    test('rapproche un nom OCR abrégé de l\'article existant', () {
      // "blanc de poule" (OCR tronqué) → "Blanc de poulet".
      expect(DoublonsService.trouverProche(catalogue, 'blanc de poule')?.nom,
          'Blanc de poulet');
    });

    test('égalité aux accents/casse près', () {
      expect(DoublonsService.trouverProche(catalogue, 'PATES')?.nom, 'Pâtes');
    });

    test('rien de proche → null (pas de faux rapprochement)', () {
      expect(DoublonsService.trouverProche(catalogue, 'Concombre'), isNull);
    });

    test('nom trop court → null (évite les faux positifs)', () {
      expect(DoublonsService.trouverProche(catalogue, 'lai'), isNull);
    });
  });
}
