import 'package:flutter_test/flutter_test.dart';
import 'package:smartcart/services/ticket_ocr_service.dart';

// Lignes réelles d'un ticket Carrefour (format hypermarché français courant),
// pour valider le parsing indépendamment de l'OCR.
void main() {
  final service = TicketOcrService();

  test('parse le format « TVA NOM QTE x P.U. MONTANT » et prend le P.U.', () {
    final res = service.parserLignes([
      'Carrefour',
      'PLOUZANÉ',
      'TVA Produit QTE x P.U. Montant €',
      '5.5% 6XOEUFS DJP SOL CR 1 x 1.54 1.54',
      '5.5% NUGGETS PLET MAXI 1 x 7.51 7.51',
      '5.5% KIWI VERT PIECE 10 x 0.75 7.50',
      'Remise immédiate -0.52',
      '5.5% 200G EMMENTAL RAPE 1 x 1.65 1.65',
      '10.0% SAND.PLT ROTI/CRUD 1 x 1.77 1.77',
      '20.0% 250G MARGAR TARTI 1 x 1.74 1.74',
    ]);

    expect(res.enseigne, 'Carrefour');
    final parNom = {for (final l in res.lignes) l.nom: l.prix};

    // Le prix retenu est le PRIX UNITAIRE (kiwi : 0,75 € et non 7,50 €).
    expect(parNom['Kiwi vert piece'], 0.75);
    expect(parNom['Nuggets plet maxi'], 7.51);
    expect(parNom['200g emmental rape'], 1.65);
    expect(parNom['Sand.plt roti/crud'], 1.77);
    // Les lignes « Remise » et l'en-tête ne créent pas d'articles.
    expect(res.lignes.any((l) => l.nom.toLowerCase().contains('remise')), isFalse);
    expect(res.lignes.any((l) => l.nom.toLowerCase().contains('produit')), isFalse);
  });

  test('s\'arrête à la zone des totaux / fidélité (pas de faux articles)', () {
    final res = service.parserLignes([
      '5.5% BANANE 5 FRUITS 1 x 0.99 0.99',
      'Total à payer 115.88€',
      // Section fidélité : « nom + prix » qui NE sont PAS des achats.
      'POMME GOLDEN FQC 0.62€',
      'TOMATE GRAPPE 0.46€',
    ]);
    expect(res.lignes.length, 1);
    expect(res.lignes.first.nom, 'Banane 5 fruits');
    expect(res.lignes.any((l) => l.nom.toLowerCase().contains('pomme')), isFalse);
  });

  test('ignore les lignes de détail au poids', () {
    final res = service.parserLignes([
      '5.5% POMME GOLDEN FQC 1 x 4.15 4.15',
      '1.736kg x 2.39€/kg',
    ]);
    expect(res.lignes.length, 1);
    expect(res.lignes.first.prix, 4.15);
  });
}
