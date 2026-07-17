import 'database_service.dart';

// Classe PUBLIQUE pour pouvoir l'utiliser depuis import_liste_dialog.dart
class LigneImport {
  final String nom;
  final String categorieNom;
  final String rayonNom;
  LigneImport({
    required this.nom,
    required this.categorieNom,
    required this.rayonNom,
  });
}

class ExportService {
  final DatabaseService _db;
  ExportService(this._db);

  /// Export : nom;categorie_maison;rayon_magasin
  Future<String> exporterCatalogue() async {
    final articles = await _db.getArticles();
    final categories = await _db.getCategories();
    final rayons = await _db.getRayons();

    final buffer = StringBuffer();
    for (final a in articles) {
      final cat = categories.where((c) => c.id == a.categorieId).firstOrNull?.nom ?? '';
      final ray = rayons.where((r) => r.id == a.rayonId).firstOrNull?.nom ?? '';
      buffer.writeln('${a.nom};$cat;$ray');
    }
    return buffer.toString();
  }

  /// Parse une ligne : "nom;categorie;rayon" ou juste "nom"
  static LigneImport? parseLigne(String ligne) {
    final l = ligne.trim();
    // Ignorer commentaires et lignes vides
    if (l.isEmpty || l.startsWith('#')) return null;

    // Nettoyer préfixes (tirets, puces, numéros)
    var nettoye = l
        .replaceFirst(RegExp(r'^[-•*·]+\s*'), '')
        .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
        .trim();

    if (nettoye.isEmpty) return null;

    if (nettoye.contains(';')) {
      final parts = nettoye.split(';');
      final nom = parts[0].trim();
      if (nom.isEmpty) return null;
      return LigneImport(
        nom: nom,
        categorieNom: parts.length > 1 ? parts[1].trim() : '',
        rayonNom: parts.length > 2 ? parts[2].trim() : '',
      );
    }

    return LigneImport(nom: nettoye, categorieNom: '', rayonNom: '');
  }
}
