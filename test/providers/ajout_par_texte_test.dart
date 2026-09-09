// Teste ArticlesListeNotifier.ajouterParTexte : la saisie rapide en une
// ligne (« 3 pommes », « lait »…) qui détecte la quantité, réutilise ou crée
// l'article, et fusionne les doublons.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/models/models.dart';
import 'package:smartcart/providers/providers.dart';
import 'package:smartcart/services/database_service.dart';
import 'package:smartcart/services/sync_service.dart';

void main() {
  late DatabaseService db;
  late ProviderContainer container;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_ajout_texte.db';
  });

  tearDownAll(() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    final d = await db.db;
    await d.delete('articles');
    await d.delete('listes');
    await d.delete('articles_liste');

    await db.insertListe(ListeCourses(id: 'liste_1', nom: 'Courses'));

    container = ProviderContainer(overrides: [
      dbServiceProvider.overrideWithValue(db),
      syncServiceProvider.overrideWithValue(SyncService(
        db,
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(signedIn: false),
      )),
    ]);
  });

  tearDown(() => container.dispose());

  test('crée l\'article manquant et détecte la quantité (« 3 pommes »)',
      () async {
    final nom = await container
        .read(articlesListeProvider('liste_1').notifier)
        .ajouterParTexte('3 pommes');

    expect(nom, 'Pommes');

    final articles = await db.getArticles();
    expect(articles.where((a) => a.nom == 'Pommes'), hasLength(1));

    final items = await db.getArticlesListe('liste_1');
    expect(items, hasLength(1));
    expect(items.single.quantite, 3);
  });

  test('réutilise un article déjà au catalogue (insensible à la casse)',
      () async {
    await db.insertArticle(Article(id: 'art_lait', nom: 'Lait'));

    await container
        .read(articlesListeProvider('liste_1').notifier)
        .ajouterParTexte('LAIT');

    final articles = await db.getArticles();
    expect(articles.where((a) => a.nom.toLowerCase() == 'lait'), hasLength(1));

    final items = await db.getArticlesListe('liste_1');
    expect(items.single.articleId, 'art_lait');
  });

  test('additionne la quantité si l\'article est déjà dans la liste', () async {
    await container
        .read(articlesListeProvider('liste_1').notifier)
        .ajouterParTexte('2 bananes');
    await container
        .read(articlesListeProvider('liste_1').notifier)
        .ajouterParTexte('3 bananes');

    final items = await db.getArticlesListe('liste_1');
    expect(items, hasLength(1)); // pas de doublon
    expect(items.single.quantite, 5); // 2 + 3
  });

  test('un texte vide n\'ajoute rien', () async {
    final nom = await container
        .read(articlesListeProvider('liste_1').notifier)
        .ajouterParTexte('   ');

    expect(nom, isNull);
    final items = await db.getArticlesListe('liste_1');
    expect(items, isEmpty);
  });
}
