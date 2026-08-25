// Vérifie les correctifs d'affichage des listes COLLABORATIVES :
//  1. articlePourLigne() reconstruit un article à partir du nom dénormalisé
//     porté par la ligne quand l'article n'est pas au catalogue (cas d'un
//     membre : les articles partagés ne sont pas dans SON catalogue) — sinon
//     la ligne était masquée et la liste paraissait vide.
//  2. deleteArticle() ne touche PAS aux lignes des listes collaboratives (leur
//     articleId « recréé » peut être nettoyé comme orphelin sur un autre
//     appareil ; sans cette protection, la liste se vidait en cascade).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/models/models.dart';
import 'package:smartcart/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_collab_affichage.db';
  });

  tearDownAll(() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  test('articlePourLigne reconstruit l\'article depuis nomArticle', () {
    // Ligne dont l'article n'est PAS au catalogue (membre d'une liste partagée),
    // mais qui porte son nom.
    final ligne = ArticleListe(
      id: 'al1',
      listeId: 'liste1',
      articleId: 'art_absent',
      nomArticle: 'Jus de raisin',
    );
    final art = articlePourLigne(ligne, const []);
    expect(art, isNotNull);
    expect(art!.nom, 'Jus de raisin');
    expect(art.id, 'art_absent');

    // Sans nom dénormalisé ET sans article au catalogue → non affichable.
    final orpheline = ArticleListe(
      id: 'al2',
      listeId: 'liste1',
      articleId: 'art_absent2',
    );
    expect(articlePourLigne(orpheline, const []), isNull);
  });

  test(
      'deleteArticle ne vide pas une liste collaborative mais nettoie une liste '
      'perso', () async {
    final db = DatabaseService();
    final dbPath = await getDatabasesPath();
    await databaseFactory
        .deleteDatabase(p.join(dbPath, DatabaseService.dbFileName));

    // Un article au catalogue, référencé à la fois par une liste PERSO et une
    // liste COLLABORATIVE.
    await db.insertArticle(Article(id: 'art1', nom: 'Lait'));
    await db.insertListe(ListeCourses(id: 'perso', nom: 'Perso'));
    await db.insertListe(
        ListeCourses(id: 'collab', nom: 'Collab', partagee: true));
    await db.insertArticleListe(ArticleListe(
        id: 'p1', listeId: 'perso', articleId: 'art1', nomArticle: 'Lait'));
    await db.insertArticleListe(ArticleListe(
        id: 'c1', listeId: 'collab', articleId: 'art1', nomArticle: 'Lait'));

    await db.deleteArticle('art1');

    // La ligne perso est nettoyée (article disparu du catalogue)…
    expect((await db.getArticlesListe('perso')), isEmpty);
    // …mais la ligne de la liste collaborative est PRÉSERVÉE.
    final collab = await db.getArticlesListe('collab');
    expect(collab.length, 1);
    expect(collab.first.nomArticle, 'Lait');
  });
}
