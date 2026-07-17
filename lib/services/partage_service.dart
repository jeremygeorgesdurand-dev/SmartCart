import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

class PartageService {

  /// Génère le texte partageable au format SmartCart importable
  String formaterListe({
    required ListeCourses liste,
    required List<ArticleListe> items,
    required List<Article> catalogue,
    required List<Rayon> rayons,
    required List<Categorie> categories,
  }) {
    final buffer = StringBuffer();

    // En-tête SmartCart (reconnu par le parser)
    buffer.writeln('=== SMARTCART LISTE ===');
    buffer.writeln('Nom: ${liste.nom}');
    if (liste.magasin != null) buffer.writeln('Magasin: ${liste.magasin}');
    buffer.writeln('---');

    for (final item in items) {
      final article = catalogue.where((a) => a.id == item.articleId).firstOrNull;
      if (article == null) continue;

      final cat = categories.where((c) => c.id == article.categorieId).firstOrNull?.nom ?? '';
      final ray = rayons.where((r) => r.id == article.rayonId).firstOrNull?.nom ?? '';
      final qte = item.quantite > 1 ? '×${item.quantite}' : '×1';
      final unite = item.unite != null ? ' ${item.unite}' : '';

      // Format: nom;quantite;unite;categorie_maison;rayon_magasin
      buffer.writeln('${article.nom};$qte$unite;$cat;$ray');
    }

    buffer.writeln('=== FIN SMARTCART ===');
    return buffer.toString();
  }

  Future<void> partagerListe({
    required ListeCourses liste,
    required String texte,
  }) async {
    await Share.share(texte, subject: '🛒 Liste ${liste.nom}');
  }

  Future<void> copierPressePapier(String texte) async {
    await Clipboard.setData(ClipboardData(text: texte));
  }
}
