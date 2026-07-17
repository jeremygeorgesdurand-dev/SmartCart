import '../models/models.dart';

class ArticleImport {
  final String nom;
  final String categorieNom;
  final String rayonNom;
  final int quantite;
  final String? unite;

  ArticleImport({
    required this.nom,
    required this.categorieNom,
    required this.rayonNom,
    this.quantite = 1,
    this.unite,
  });
}

class ListeImportResult {
  final String nomListe;
  final String? magasin;
  final List<ArticleImport> articles;

  ListeImportResult({
    required this.nomListe,
    required this.magasin,
    required this.articles,
  });
}

class ListePartageService {
  /// Parse un texte SmartCart partagé
  /// Format attendu :
  ///   === SMARTCART LISTE ===
  ///   Nom: Ma liste
  ///   Magasin: Carrefour (optionnel)
  ///   ---
  ///   Pain;×1;;Boulangerie
  ///   Lait;×2;L;Frigo;Produits frais
  ///   === FIN SMARTCART ===
  static ListeImportResult? parserTexte(String texte) {
    final lignes = texte.split('\n').map((l) => l.trim()).toList();

    // Vérifier l'en-tête
    final headerIdx = lignes.indexWhere((l) => l == '=== SMARTCART LISTE ===');
    if (headerIdx == -1) return null;

    String nomListe = 'Liste importée';
    String? magasin;
    final articles = <ArticleImport>[];
    bool inBody = false;

    for (int i = headerIdx + 1; i < lignes.length; i++) {
      final ligne = lignes[i];

      if (ligne == '=== FIN SMARTCART ===') break;

      if (ligne.startsWith('Nom: ')) {
        nomListe = ligne.substring(5).trim();
        continue;
      }
      if (ligne.startsWith('Magasin: ')) {
        magasin = ligne.substring(9).trim();
        continue;
      }
      if (ligne == '---') {
        inBody = true;
        continue;
      }

      if (!inBody || ligne.isEmpty) continue;

      // Parser ligne article: nom;qte;unite;categorie;rayon
      final parts = ligne.split(';');
      if (parts.isEmpty || parts[0].trim().isEmpty) continue;

      final nom = parts[0].trim();

      // Quantité: ×2 ou ×2L
      int qte = 1;
      String? unite;
      if (parts.length > 1) {
        final qteStr = parts[1].trim();
        final reQte = RegExp(r'^×(\d+)\s*(.*)$');
        final m = reQte.firstMatch(qteStr);
        if (m != null) {
          qte = int.tryParse(m.group(1)!) ?? 1;
          final u = m.group(2)?.trim();
          if (u != null && u.isNotEmpty) unite = u;
        }
      }

      final catNom = parts.length > 2 ? parts[2].trim() : '';
      final rayNom = parts.length > 3 ? parts[3].trim() : '';

      articles.add(ArticleImport(
        nom: nom,
        categorieNom: catNom,
        rayonNom: rayNom,
        quantite: qte,
        unite: unite,
      ));
    }

    if (articles.isEmpty) return null;

    return ListeImportResult(
      nomListe: nomListe,
      magasin: magasin,
      articles: articles,
    );
  }
}
