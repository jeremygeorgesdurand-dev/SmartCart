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

  /// Construit le JSON d'un partage de CATALOGUE : uniquement les catégories,
  /// rayons et articles (pas les listes ni les prix). C'est ce qu'on partage
  /// avec une autre personne pour lui transmettre son organisation d'articles,
  /// sans lui envoyer ses listes de courses ni ses prix.
  Future<String> exporterCatalogueVersJson() async {
    final categories = await _db.getCategories();
    final rayons = await _db.getRayons();
    final articles = await _db.getArticles();
    return const JsonEncoder.withIndent('  ').convert({
      'version': _version,
      'type': 'catalogue',
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'rayons': rayons.map((r) => r.toMap()).toList(),
      'articles': articles.map((a) => a.toMap()).toList(),
    });
  }

  /// Génère le fichier de partage du catalogue et ouvre le menu de partage
  /// natif (l'autre personne l'ouvre et l'importe pour fusionner dans le sien).
  Future<void> partagerCatalogue() async {
    final json = await exporterCatalogueVersJson();
    final dir = await getTemporaryDirectory();
    final date = DateTime.now();
    final nomFichier = 'smartcart_catalogue_'
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}'
        '.json';
    final file = File('${dir.path}/$nomFichier');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)],
        subject: 'Catalogue SmartCart (articles + catégories)');
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

  /// Importe UNIQUEMENT un catalogue (catégories, rayons, articles) en
  /// FUSIONNANT par NOM — jamais de doublon de catégorie/rayon, et chaque
  /// article importé est rattaché à la catégorie/au rayon LOCAL du même nom
  /// (les id diffèrent d'un compte à l'autre, c'est ce qui donnait de
  /// « mauvaises catégories »). N'ajoute JAMAIS de liste ni de prix, même si
  /// le fichier en contient (un fichier de sauvegarde complète en a).
  Future<RestaurationResultat> importerCatalogue(String contenu) async {
    final data = jsonDecode(contenu);
    if (data is! Map<String, dynamic> || data['version'] == null) {
      throw const FormatException(
          "Ce fichier n'est pas une sauvegarde SmartCart valide");
    }
    return fusionnerCatalogue(
      categories: [
        for (final c in (data['categories'] as List? ?? []))
          Categorie.fromMap(c as Map<String, dynamic>)
      ],
      rayons: [
        for (final r in (data['rayons'] as List? ?? []))
          Rayon.fromMap(r as Map<String, dynamic>)
      ],
      articles: [
        for (final a in (data['articles'] as List? ?? []))
          Article.fromMap(a as Map<String, dynamic>)
      ],
    );
  }

  /// Fusionne un catalogue (catégories, rayons, articles) dans le catalogue
  /// LOCAL, par NOM (jamais de doublon, articles rattachés à la bonne catégorie
  /// locale). Réutilisé par l'import fichier ET par le catalogue partagé en
  /// temps réel. N'ajoute jamais de liste ni de prix.
  Future<RestaurationResultat> fusionnerCatalogue({
    required List<Categorie> categories,
    required List<Rayon> rayons,
    required List<Article> articles,
  }) async {
    // Catégories : réutilise la locale du même nom, sinon crée. On garde une
    // table importedId → localId pour réaffecter les articles ensuite.
    final catParNom = {
      for (final c in await _db.getCategories()) _norm(c.nom): c.id
    };
    final catIdMap = <String, String>{};
    var nbCategories = 0;
    for (final cat in categories) {
      final local = catParNom[_norm(cat.nom)];
      if (local != null) {
        catIdMap[cat.id] = local;
      } else {
        await _db.insertCategorie(cat);
        catIdMap[cat.id] = cat.id;
        catParNom[_norm(cat.nom)] = cat.id;
        nbCategories++;
      }
    }

    // Rayons : idem.
    final rayonParNom = {
      for (final r in await _db.getRayons()) _norm(r.nom): r.id
    };
    final rayonIdMap = <String, String>{};
    var nbRayons = 0;
    for (final ray in rayons) {
      final local = rayonParNom[_norm(ray.nom)];
      if (local != null) {
        rayonIdMap[ray.id] = local;
      } else {
        await _db.insertRayon(ray);
        rayonIdMap[ray.id] = ray.id;
        rayonParNom[_norm(ray.nom)] = ray.id;
        nbRayons++;
      }
    }

    // Articles : fusion par nom (pas de doublon), catégorie/rayon réaffectés.
    final artParNom = {
      for (final a in await _db.getArticles()) _norm(a.nom): a
    };
    var nbArticles = 0;
    for (final art in articles) {
      final catLocal =
          art.categorieId != null ? catIdMap[art.categorieId] : null;
      final rayonLocal = art.rayonId != null ? rayonIdMap[art.rayonId] : null;
      final existant = artParNom[_norm(art.nom)];
      if (existant != null) {
        // Ne pas dupliquer : on complète seulement la catégorie/le rayon
        // manquants, sans écraser ceux que l'utilisateur a déjà mis.
        await _db.insertArticle(existant.copyWith(
          categorieId: existant.categorieId ?? catLocal,
          rayonId: existant.rayonId ?? rayonLocal,
        ));
      } else {
        final nouveau = Article(
          id: art.id,
          nom: art.nom,
          categorieId: catLocal,
          rayonId: rayonLocal,
          barcode: art.barcode,
          marque: art.marque,
          imageUrl: art.imageUrl,
        );
        await _db.insertArticle(nouveau);
        artParNom[_norm(art.nom)] = nouveau;
        nbArticles++;
      }
    }

    return RestaurationResultat(
      categories: nbCategories,
      rayons: nbRayons,
      articles: nbArticles,
      listes: 0,
      articlesListe: 0,
      prixArticles: 0,
    );
  }

  // Normalisation d'un nom pour le rapprochement (accents/casse/espaces).
  static String _norm(String s) {
    const a = 'àâäéèêëïîôöùûüçñ';
    const b = 'aaaeeeeiioouuucn';
    var out = s.trim().toLowerCase();
    for (var i = 0; i < a.length; i++) {
      out = out.replaceAll(a[i], b[i]);
    }
    return out.replaceAll(RegExp(r'\s+'), ' ');
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
