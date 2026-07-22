import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'package:uuid/uuid.dart';

class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org';
  static const _uuid = Uuid();

  /// Recherche d'articles par nom (en français)
  Future<List<Article>> searchByName(String query) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&search_simple=1&action=process&json=1&lc=fr&cc=fr&page_size=20',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final products = data['products'] as List? ?? [];

      // Exiger `product_name_fr` spécifiquement écartait silencieusement
      // une bonne partie des résultats (beurre, basilic, etc.) : beaucoup
      // de produits n'ont qu'un `product_name` générique renseigné sur Open
      // Food Facts, sans traduction française dédiée, alors qu'ils ont bien
      // un nom exploitable. On accepte les deux, comme le fait déjà le
      // mapping juste en dessous.
      return products
          .where((p) =>
              ((p['product_name_fr'] as String?)?.isNotEmpty ?? false) ||
              ((p['product_name'] as String?)?.isNotEmpty ?? false))
          .map((p) => Article(
                id: _uuid.v4(),
                nom: p['product_name_fr'] ?? p['product_name'] ?? 'Inconnu',
                barcode: p['code'],
                marque: p['brands'],
                imageUrl: p['image_front_small_url'],
                // Tentative de mapping catégorie OFF → catégorie locale
                categorieId: _mapCategorie(p['pnns_groups_1']),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Recherche par code-barres
  Future<Article?> searchByBarcode(String barcode) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v0/product/$barcode.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 1) return null;

      final p = data['product'];
      return Article(
        id: _uuid.v4(),
        nom: p['product_name_fr'] ?? p['product_name'] ?? barcode,
        barcode: barcode,
        marque: p['brands'],
        imageUrl: p['image_front_small_url'],
        categorieId: _mapCategorie(p['pnns_groups_1']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Récupère les infos nutritionnelles d'un produit à la volée (non persistées)
  Future<ProductDetails?> fetchDetails(String barcode) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v0/product/$barcode.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 1) return null;

      final p = data['product'] as Map<String, dynamic>;
      final ingredients = p['ingredients_text_fr'] ?? p['ingredients_text'];
      return ProductDetails(
        nutriscore: (p['nutriscore_grade'] as String?)?.toLowerCase(),
        ingredients: (ingredients is String && ingredients.isNotEmpty) ? ingredients : null,
        quantite: p['quantity'],
      );
    } catch (_) {
      return null;
    }
  }

  /// Mapping approximatif des groupes Open Food Facts → catégories maison
  String? _mapCategorie(String? pnns) {
    if (pnns == null) return null;
    final p = pnns.toLowerCase();
    if (p.contains('dairy') || p.contains('lait') || p.contains('fromage')) return 'cat_frigo';
    if (p.contains('surgelé') || p.contains('frozen')) return 'cat_congelateur';
    if (p.contains('viande') || p.contains('poisson') || p.contains('fruits de mer')) return 'cat_frigo';
    if (p.contains('boisson') || p.contains('beverage')) return 'cat_placards';
    if (p.contains('hygiene') || p.contains('beauté')) return 'cat_hygiene';
    if (p.contains('entretien') || p.contains('cleaning')) return 'cat_menage';
    return 'cat_placards';
  }
}

/// Infos nutritionnelles d'un produit, récupérées à la demande depuis
/// Open Food Facts (non persistées en base, pas de champ Article associé)
class ProductDetails {
  final String? nutriscore; // lettre a-e, ou null si inconnu
  final String? ingredients;
  final String? quantite;

  const ProductDetails({this.nutriscore, this.ingredients, this.quantite});

  bool get aDesInfos => nutriscore != null || ingredients != null || quantite != null;
}
