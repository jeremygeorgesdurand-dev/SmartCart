import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

  /// Génère un PDF de la liste, regroupé par rayon (ordre du magasin),
  /// avec cases à cocher pour une utilisation papier en magasin.
  Future<Uint8List> genererPdf({
    required ListeCourses liste,
    required List<ArticleListe> items,
    required List<Article> catalogue,
    required List<Rayon> rayons,
  }) async {
    final doc = pw.Document();

    final parRayon = <String, List<ArticleListe>>{};
    for (final item in items) {
      final article = catalogue.where((a) => a.id == item.articleId).firstOrNull;
      if (article == null) continue;
      final rayonNom =
          rayons.where((r) => r.id == article.rayonId).firstOrNull?.nom ??
              'Sans rayon';
      (parRayon[rayonNom] ??= []).add(item);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(liste.nom,
                style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          if (liste.magasin != null)
            pw.Text(liste.magasin!,
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          for (final entry in parRayon.entries) ...[
            pw.Text(entry.key,
                style: const pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            for (final item in entry.value)
              pw.Row(
                children: [
                  pw.Container(
                    width: 14, height: 14,
                    margin: const pw.EdgeInsets.only(right: 8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      catalogue
                              .where((a) => a.id == item.articleId)
                              .firstOrNull
                              ?.nom ??
                          'Article',
                    ),
                  ),
                  if (item.quantite > 1) pw.Text('×${item.quantite}'),
                ],
              ),
            pw.SizedBox(height: 12),
          ],
        ],
      ),
    );

    return doc.save();
  }

  Future<void> partagerPdf({
    required ListeCourses liste,
    required Uint8List bytes,
  }) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'liste_${liste.nom.replaceAll(RegExp(r'[^\w]+'), '_')}.pdf',
    );
  }
}
