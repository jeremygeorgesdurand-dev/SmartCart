// Teste RecettesNotifier.genererListe : le cœur de la fonctionnalité
// recettes (transformer une liste d'ingrédients en liste de courses
// réelle, avec création des articles manquants au catalogue).
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
    DatabaseService.dbFileName = 'smartcart_test_recettes.db';
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
    await d.delete('recettes');

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

  test('génère une nouvelle liste avec un article créé pour chaque ingrédient',
      () async {
    final recette = Recette(
      id: 'recette_1',
      nom: 'Pâtes carbonara',
      portions: 4,
      ingredients: [
        IngredientRecette(nom: 'Pâtes', quantite: 500, unite: 'g'),
        IngredientRecette(nom: 'Lardons', quantite: 200, unite: 'g'),
        IngredientRecette(nom: 'Œufs', quantite: 3),
      ],
    );

    await container
        .read(recettesNotifierProvider.notifier)
        .genererListe(recette);

    final listes = await db.getListes();
    expect(listes, hasLength(1));
    expect(listes.single.nom, 'Pâtes carbonara');

    final items = await db.getArticlesListe(listes.single.id);
    expect(items, hasLength(3));

    final articles = await db.getArticles();
    expect(articles.map((a) => a.nom), containsAll(['Pâtes', 'Lardons', 'Œufs']));
  });

  test('réutilise un article déjà présent au catalogue au lieu d\'en créer un doublon',
      () async {
    await db.insertArticle(Article(id: 'art_existant', nom: 'Farine'));

    final recette = Recette(
      id: 'recette_2',
      nom: 'Gâteau',
      ingredients: [IngredientRecette(nom: 'Farine', quantite: 250, unite: 'g')],
    );

    await container
        .read(recettesNotifierProvider.notifier)
        .genererListe(recette);

    final articles = await db.getArticles();
    expect(articles.where((a) => a.nom == 'Farine'), hasLength(1));

    final listes = await db.getListes();
    final items = await db.getArticlesListe(listes.single.id);
    expect(items.single.articleId, 'art_existant');
  });

  test('génère dans une liste existante sans dupliquer un ingrédient déjà présent',
      () async {
    final liste = ListeCourses(id: 'liste_cible', nom: 'Courses de la semaine');
    await db.insertListe(liste);
    await db.insertArticle(Article(id: 'art_lait', nom: 'Lait'));
    await db.insertArticleListe(ArticleListe(
        id: 'al_existant', listeId: liste.id, articleId: 'art_lait', quantite: 1));

    final recette = Recette(
      id: 'recette_3',
      nom: 'Crêpes',
      ingredients: [
        IngredientRecette(nom: 'Lait', quantite: 500, unite: 'ml'),
        IngredientRecette(nom: 'Farine', quantite: 250, unite: 'g'),
      ],
    );

    await container
        .read(recettesNotifierProvider.notifier)
        .genererListe(recette, listeIdExistante: liste.id);

    final listes = await db.getListes();
    expect(listes, hasLength(1)); // aucune nouvelle liste créée

    final items = await db.getArticlesListe(liste.id);
    expect(items, hasLength(2)); // lait (déjà là) + farine (ajoutée), pas de doublon
  });
}
