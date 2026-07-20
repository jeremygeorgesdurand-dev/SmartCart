// Teste le parsing de la réponse Open Prices (prices.openfoodfacts.org),
// sans appel réseau réel : http.Client est mocké via http.testing.MockClient
// (fourni par le package http lui-même, pas de dépendance supplémentaire).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:smartcart/services/open_prices_service.dart';

http.Response _reponse(List<Map<String, dynamic>> items) {
  return http.Response(
    jsonEncode({
      'items': items,
      'page': 1,
      'pages': 1,
      'size': items.length,
      'total': items.length,
    }),
    200,
  );
}

Map<String, dynamic> _item({
  required double prix,
  required String magasin,
  String date = '2024-01-11',
  String currency = 'EUR',
}) =>
    {
      'price': prix,
      'currency': currency,
      'date': date,
      'location': {'osm_brand': magasin},
    };

void main() {
  test('parse une réponse avec plusieurs magasins et trie par prix croissant',
      () async {
    final client = MockClient((request) async => _reponse([
          _item(prix: 3.2, magasin: 'Carrefour'),
          _item(prix: 2.5, magasin: 'Lidl'),
        ]));
    final service = OpenPricesService(client: client);

    final resultats = await service.chercherParBarcode('123456');

    expect(resultats, hasLength(2));
    expect(resultats.first.magasin, 'Lidl');
    expect(resultats.first.prix, 2.5);
    expect(resultats.last.magasin, 'Carrefour');
  });

  test('ne garde que le prix le plus récent par magasin', () async {
    final client = MockClient((request) async => _reponse([
          _item(prix: 3.0, magasin: 'Carrefour', date: '2023-01-01'),
          _item(prix: 3.5, magasin: 'Carrefour', date: '2024-06-01'),
        ]));
    final service = OpenPricesService(client: client);

    final resultats = await service.chercherParBarcode('123456');

    expect(resultats, hasLength(1));
    expect(resultats.first.prix, 3.5);
  });

  test('retourne une liste vide sur erreur HTTP (best effort, pas d\'exception)',
      () async {
    final client = MockClient((request) async => http.Response('', 500));
    final service = OpenPricesService(client: client);

    final resultats = await service.chercherParBarcode('123456');

    expect(resultats, isEmpty);
  });

  test('retourne une liste vide si le JSON est invalide', () async {
    final client = MockClient((request) async => http.Response('pas du json', 200));
    final service = OpenPricesService(client: client);

    final resultats = await service.chercherParBarcode('123456');

    expect(resultats, isEmpty);
  });
}
