import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/open_food_facts_service.dart';
import 'providers.dart';

/// Infos nutritionnelles d'un produit, récupérées à la demande depuis
/// Open Food Facts via son code-barres. Non mises en cache entre les
/// ouvertures : chaque consultation refait l'appel réseau.
final offDetailsProvider =
    FutureProvider.family<ProductDetails?, String>((ref, barcode) {
  return ref.read(offServiceProvider).fetchDetails(barcode);
});
