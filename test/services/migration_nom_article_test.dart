// Vérifie la migration v15 → v16 : ajout de la colonne articles_liste.nomArticle
// ET backfill du nom depuis l'article du catalogue tant qu'il existe encore.
// Sans ce backfill, une liste collaborative perdait le nom de ses articles au
// premier nettoyage du catalogue et affichait moins d'articles que le widget.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_migr_nom.db';
  });

  tearDownAll(() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  test('v16 ajoute nomArticle et le remplit depuis le catalogue', () async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    await databaseFactory.deleteDatabase(path);

    // Base v15 minimale : articles_liste SANS colonne nomArticle.
    final v15 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 15,
        onCreate: (db, version) async {
          await db.execute(
              'CREATE TABLE articles (id TEXT PRIMARY KEY, nom TEXT NOT NULL, '
              'categorieId TEXT, rayonId TEXT, barcode TEXT, marque TEXT, source TEXT)');
          await db.execute('''
            CREATE TABLE articles_liste (
              id TEXT PRIMARY KEY, listeId TEXT NOT NULL, articleId TEXT NOT NULL,
              quantite INTEGER DEFAULT 1, unite TEXT, note TEXT,
              coche INTEGER DEFAULT 0, catNom TEXT, catCouleur INTEGER,
              rayonNom TEXT, rayonCouleur INTEGER, rayonOrdre INTEGER,
              modifiePar TEXT
            )
          ''');
        },
      ),
    );
    await v15.insert('articles', {'id': 'art1', 'nom': 'Jus de raisin'});
    // Ligne dont l'article EXISTE au catalogue → doit être remplie.
    await v15.insert('articles_liste',
        {'id': 'al1', 'listeId': 'L1', 'articleId': 'art1'});
    // Ligne orpheline (article absent) → reste sans nom.
    await v15.insert('articles_liste',
        {'id': 'al2', 'listeId': 'L1', 'articleId': 'absent'});
    await v15.close();

    // Ouvre via le code réel → déclenche onUpgrade v15 → v16.
    final migrated = await DatabaseService().db;
    final al1 = (await migrated
            .query('articles_liste', where: 'id = ?', whereArgs: ['al1']))
        .first;
    final al2 = (await migrated
            .query('articles_liste', where: 'id = ?', whereArgs: ['al2']))
        .first;

    expect(al1['nomArticle'], 'Jus de raisin');
    expect(al2['nomArticle'], isNull);
  });
}
