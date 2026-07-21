import 'dart:convert';
import 'package:http/http.dart' as http;

/// Un prix observé, récupéré depuis Open Prices (prices.openfoodfacts.org),
/// la base de prix communautaire du projet Open Food Facts.
class PrixTrouve {
  final String magasin;
  final double prix;
  final String devise;
  final DateTime? date;

  const PrixTrouve({
    required this.magasin,
    required this.prix,
    required this.devise,
    this.date,
  });
}

class OpenPricesService {
  static const _baseUrl = 'https://prices.openfoodfacts.org/api/v1';

  final http.Client _client;
  OpenPricesService({http.Client? client}) : _client = client ?? http.Client();

  /// Cherche les prix récents connus pour ce code-barres. Retourne au
  /// maximum un prix par magasin (le plus récent), triés du moins cher au
  /// plus cher. Liste vide si rien trouvé ou en cas d'erreur réseau —
  /// c'est une recherche "best effort", jamais bloquante.
  Future<List<PrixTrouve>> chercherParBarcode(String barcode) async {
    try {
      final uri = Uri.parse('$_baseUrl/prices'
          '?product_code=${Uri.encodeComponent(barcode)}'
          '&size=50');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List? ?? [];

      final parMagasin = <String, PrixTrouve>{};
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final prixValeur = (map['price'] as num?)?.toDouble();
        if (prixValeur == null) continue;

        final location = map['location'] as Map<String, dynamic>?;
        final magasin = (location?['osm_brand'] as String?) ??
            (location?['osm_name'] as String?) ??
            'Magasin inconnu';

        final date = DateTime.tryParse(map['date']?.toString() ?? '');
        final existant = parMagasin[magasin];
        if (existant == null ||
            (date != null &&
                (existant.date == null || date.isAfter(existant.date!)))) {
          parMagasin[magasin] = PrixTrouve(
            magasin: magasin,
            prix: prixValeur,
            devise: map['currency'] as String? ?? 'EUR',
            date: date,
          );
        }
      }

      final resultats = parMagasin.values.toList()
        ..sort((a, b) => a.prix.compareTo(b.prix));
      return resultats;
    } catch (_) {
      return [];
    }
  }
}
