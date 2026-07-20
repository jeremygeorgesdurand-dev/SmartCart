import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'database_service.dart';

/// Sauvegarde/restauration manuelle complète de toutes les données locales
/// dans un unique fichier JSON — indépendant de la synchro cloud, utile en
/// filet de sécurité ou pour changer d'appareil sans compte.
class BackupService {
  static const _version = 1;

  final DatabaseService _db;
  BackupService(this._db);

  /// Construit le JSON de sauvegarde (sans écrire de fichier), pour les
  /// tests et pour exporter().
  Future<String> exporterVersJson() async {
    final data = await _construireExport();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<Map<String, dynamic>> _construireExport() async {
    final categories = await _db.getCategories();
    final rayons = await _db.getRayons();
    final articles = await _db.getArticles();
    final listes = await _db.getListes(inclureArchivees: true);
    final prix = await _db.getPrixArticles();
    final recettes = await _db.getRecettes();

    final articlesListe = <Map<String, dynamic>>[];
    final prixHistorique = <Map<String, dynamic>>[];
    for (final liste in listes) {
      final items = await _db.getArticlesListe(liste.id);
      articlesListe.addAll(items.map((i) => i.toMap()));
    }
    for (final a in articles) {
      final h = await _db.getHistoriquePrix(a.id);
      prixHistorique.addAll(h.map((e) => e.toMap()));
    }

    return {
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'rayons': rayons.map((r) => r.toMap()).toList(),
      'articles': articles.map((a) => a.toMap()).toList(),
      'listes': listes.map((l) => l.toMap()).toList(),
      'articlesListe': articlesListe,
      'prixArticles': prix.map((p) => p.toMap()).toList(),
      'prixHistorique': prixHistorique,
      'recettes': recettes.map((r) => r.toMap()).toList(),
    };
  }

  /// Génère le fichier de sauvegarde et ouvre le menu de partage natif
  /// (Fichiers, Drive, e-mail…) pour que l'utilisateur choisisse où le
  /// conserver.
  Future<void> exporter() async {
    final json = await exporterVersJson();

    final dir = await getTemporaryDirectory();
    final date = DateTime.now();
    final nomFichier = 'smartcart_sauvegarde_'
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}'
        '.json';
    final file = File('${dir.path}/$nomFichier');
    await file.writeAsString(json);

    await Share.shareXFiles([XFile(file.path)],
        subject: 'Sauvegarde SmartCart du ${date.day}/${date.month}/${date.year}');
  }

  /// Restaure une sauvegarde depuis son contenu JSON (texte brut). Les
  /// entités existantes (même id) sont remplacées ; rien n'est supprimé.
  /// Lance une [FormatException] si le fichier n'est pas une sauvegarde
  /// SmartCart valide.
  Future<RestaurationResultat> restaurer(String contenu) async {
    final data = jsonDecode(contenu);
    if (data is! Map<String, dynamic> || data['version'] == null) {
      throw const FormatException("Ce fichier n'est pas une sauvegarde SmartCart valide");
    }

    var categories = 0, rayons = 0, articles = 0, listes = 0, articlesListe = 0, prix = 0;
    var prixHistorique = 0, recettes = 0;

    for (final c in (data['categories'] as List? ?? [])) {
      await _db.insertCategorie(Categorie.fromMap(c as Map<String, dynamic>));
      categories++;
    }
    for (final r in (data['rayons'] as List? ?? [])) {
      await _db.insertRayon(Rayon.fromMap(r as Map<String, dynamic>));
      rayons++;
    }
    for (final a in (data['articles'] as List? ?? [])) {
      await _db.insertArticle(Article.fromMap(a as Map<String, dynamic>));
      articles++;
    }
    for (final l in (data['listes'] as List? ?? [])) {
      await _db.insertListe(ListeCourses.fromMap(l as Map<String, dynamic>));
      listes++;
    }
    for (final al in (data['articlesListe'] as List? ?? [])) {
      await _db.insertArticleListe(ArticleListe.fromMap(al as Map<String, dynamic>));
      articlesListe++;
    }
    for (final p in (data['prixArticles'] as List? ?? [])) {
      await _db.setPrixArticle(PrixArticle.fromMap(p as Map<String, dynamic>));
      prix++;
    }
    for (final h in (data['prixHistorique'] as List? ?? [])) {
      await _db.ajouterHistoriquePrix(PrixHistorique.fromMap(h as Map<String, dynamic>));
      prixHistorique++;
    }
    for (final r in (data['recettes'] as List? ?? [])) {
      await _db.insertRecette(Recette.fromMap(r as Map<String, dynamic>));
      recettes++;
    }

    return RestaurationResultat(
      categories: categories,
      rayons: rayons,
      articles: articles,
      listes: listes,
      articlesListe: articlesListe,
      prixArticles: prix,
      prixHistorique: prixHistorique,
      recettes: recettes,
    );
  }
}

class RestaurationResultat {
  final int categories;
  final int rayons;
  final int articles;
  final int listes;
  final int articlesListe;
  final int prixArticles;
  final int prixHistorique;
  final int recettes;

  const RestaurationResultat({
    required this.categories,
    required this.rayons,
    required this.articles,
    required this.listes,
    required this.articlesListe,
    required this.prixArticles,
    this.prixHistorique = 0,
    this.recettes = 0,
  });

  int get total =>
      categories +
      rayons +
      articles +
      listes +
      articlesListe +
      prixArticles +
      prixHistorique +
      recettes;
}
