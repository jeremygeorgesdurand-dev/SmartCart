// Vérifie que la migration de schéma v3 → v4 (prix par magasin) ne perd
// aucune donnée existante : on simule une base v3 réelle (créée par du SQL
// brut, comme le ferait une install existante de l'app), puis on l'ouvre
// via DatabaseService (v4) et on vérifie que l'ancien prix est toujours là.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_migration.db';
  });

  tearDownAll(() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  test(
      'un prix_articles v3 (articleId PRIMARY KEY, sans magasin) survit à la '
      "migration vers v4 avec magasin=''", () async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    await databaseFactory.deleteDatabase(path);

    // Simule une base v3 existante (schéma minimal suffisant pour la
    // migration testée).
    final v3 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE prix_articles (
              articleId TEXT PRIMARY KEY,
              prix REAL NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE listes (
              id TEXT PRIMARY KEY, nom TEXT NOT NULL, createdAt TEXT NOT NULL,
              magasin TEXT, archivee INTEGER DEFAULT 0,
              partagee INTEGER DEFAULT 0, code TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE rayons (
              id TEXT PRIMARY KEY, nom TEXT NOT NULL, ordre INTEGER NOT NULL,
              magasin TEXT, couleur INTEGER DEFAULT 6296528
            )
          ''');
        },
      ),
    );
    await v3.insert('prix_articles', {'articleId': 'article_lait', 'prix': 1.5});
    await v3.close();

    // Ouvre via le code applicatif réel (déclenche onUpgrade v3 → v4).
    final migrated = await DatabaseService().db;
    final rows = await migrated.query('prix_articles');

    expect(rows, hasLength(1));
    expect(rows.first['articleId'], 'article_lait');
    expect(rows.first['magasin'], '');
    expect((rows.first['prix'] as num).toDouble(), 1.5);

    // La nouvelle contrainte composite doit permettre un 2e prix pour le
    // même article dans un autre magasin, sans écraser le premier.
    await migrated.insert('prix_articles',
        {'articleId': 'article_lait', 'magasin': 'Carrefour', 'prix': 1.2});
    final apres = await migrated.query('prix_articles',
        where: 'articleId = ?', whereArgs: ['article_lait']);
    expect(apres, hasLength(2));

    // v4 → v5 : la table prix_historique doit exister et être utilisable,
    // même pour une base qui vient d'être migrée depuis v3.
    await migrated.insert('prix_historique', {
      'id': 'hist_1',
      'articleId': 'article_lait',
      'magasin': '',
      'prix': 1.5,
      'date': DateTime.now().toIso8601String(),
    });
    final hist = await migrated.query('prix_historique');
    expect(hist, hasLength(1));

    // v6 → v7 : couleur de liste ajoutée, et les rayons par défaut restés
    // sur la couleur de repli (bug d'insertion historique) sont corrigés.
    await migrated.insert('rayons', {
      'id': 'ray_fruits',
      'nom': 'Fruits & Légumes',
      'ordre': 0,
      'couleur': 6296528, // valeur de repli laissée par le bug d'origine
    });
    // (la migration tourne déjà à l'ouverture ci-dessus ; on vérifie l'état
    // final directement)
    final listesCols =
        await migrated.rawQuery("PRAGMA table_info(listes)");
    expect(listesCols.map((c) => c['name']), contains('couleur'));
  });

  test(
      'une installation fraîche (onCreate direct, jamais migrée) peut '
      'insérer une liste avec une couleur sans erreur', () async {
    DatabaseService.dbFileName = 'smartcart_test_migration_fresh.db';
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    await databaseFactory.deleteDatabase(path);

    final db = await DatabaseService().db;
    // Doit réussir : la colonne couleur doit exister dès la création
    // (CREATE TABLE), pas seulement via une migration ultérieure — sinon
    // toute nouvelle installation de l'app plante au premier ajout de
    // liste (bug déjà rencontré une fois avec partagee/code).
    await db.insert('listes', {
      'id': 'liste_neuve',
      'nom': 'Test',
      'createdAt': DateTime.now().toIso8601String(),
      'archivee': 0,
      'partagee': 0,
      'couleur': 0xFF1ABC9C,
    });
    final rows = await db.query('listes');
    expect(rows, hasLength(1));

    await databaseFactory.deleteDatabase(path);
  });
}
