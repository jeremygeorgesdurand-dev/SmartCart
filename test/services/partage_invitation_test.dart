// Teste les helpers d'invitation : construction du lien profond et
// extraction du code depuis un texte scanné/collé (code brut ou lien).
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcart/services/partage_service.dart';

void main() {
  group('lienInvitation', () {
    test('construit un lien smartcart://rejoindre/CODE', () {
      expect(PartageService.lienInvitation('ABC123'),
          'smartcart://rejoindre/ABC123');
    });
  });

  group('codeDepuisTexte', () {
    test('rend le code brut inchangé', () {
      expect(PartageService.codeDepuisTexte('ABC123'), 'ABC123');
    });

    test('nettoie les espaces autour d\'un code brut', () {
      expect(PartageService.codeDepuisTexte('  ABC123  '), 'ABC123');
    });

    test('extrait le code d\'un lien par segment de chemin', () {
      expect(PartageService.codeDepuisTexte('smartcart://rejoindre/ABC123'),
          'ABC123');
    });

    test('extrait le code d\'un lien par paramètre de requête', () {
      expect(
          PartageService.codeDepuisTexte('smartcart://rejoindre?code=ABC123'),
          'ABC123');
    });

    test('ignore un lien d\'un autre schéma et rend le texte tel quel', () {
      expect(PartageService.codeDepuisTexte('https://exemple.com/ABC123'),
          'https://exemple.com/ABC123');
    });
  });
}
