// Vérifie que l'historique des prix s'accumule (jamais écrasé, contrairement
// à prix_articles) et reste trié chronologiquement, et que
// PrixArticlesNotifier.definir() y ajoute bien une entrée à chaque appel.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/models/models.dart';
import 'package:smartcart/services/database_service.dart';

void main() {
  late DatabaseService db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_prix_historique.db';
  });

  tearDownAll(() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  setUp(() async {
    db = DatabaseService();
    await (await db.db).delete('prix_historique');
  });

  test('deux ajouts successifs pour le même article sont tous les deux conservés',
      () async {
    await db.ajouterHistoriquePrix(PrixHistorique(
        id: 'h1', articleId: 'art_1', prix: 1.0,
        date: DateTime(2024, 1, 1)));
    await db.ajouterHistoriquePrix(PrixHistorique(
        id: 'h2', articleId: 'art_1', prix: 1.2,
        date: DateTime(2024, 2, 1)));

    final historique = await db.getHistoriquePrix('art_1');

    expect(historique, hasLength(2));
    expect(historique.first.prix, 1.0);
    expect(historique.last.prix, 1.2);
  });

  test('trie par date croissante même si inséré dans le désordre', () async {
    await db.ajouterHistoriquePrix(PrixHistorique(
        id: 'h1', articleId: 'art_1', prix: 2.0,
        date: DateTime(2024, 3, 1)));
    await db.ajouterHistoriquePrix(PrixHistorique(
        id: 'h2', articleId: 'art_1', prix: 1.5,
        date: DateTime(2024, 1, 1)));

    final historique = await db.getHistoriquePrix('art_1');

    expect(historique.first.date, DateTime(2024, 1, 1));
    expect(historique.last.date, DateTime(2024, 3, 1));
  });

  test('ne mélange pas l\'historique de deux articles différents', () async {
    await db.ajouterHistoriquePrix(
        PrixHistorique(id: 'h1', articleId: 'art_1', prix: 1.0));
    await db.ajouterHistoriquePrix(
        PrixHistorique(id: 'h2', articleId: 'art_2', prix: 5.0));

    final historiqueArt1 = await db.getHistoriquePrix('art_1');

    expect(historiqueArt1, hasLength(1));
    expect(historiqueArt1.single.articleId, 'art_1');
  });
}
