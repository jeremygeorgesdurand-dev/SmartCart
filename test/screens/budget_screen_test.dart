// Tests widget de l'écran Budget, en particulier la comparaison de prix
// par magasin ajoutée récemment (PrixArticle.magasin) : c'est la partie la
// plus récente et la moins couverte, donc la plus utile à tester.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/models/models.dart';
import 'package:smartcart/providers/providers.dart';
import 'package:smartcart/screens/budget_screen.dart';
import 'package:smartcart/services/database_service.dart';
import 'package:smartcart/services/sync_service.dart';

// Plus long que dans les autres fichiers de test : ExpansionTile anime son
// ouverture/fermeture (~200ms), il faut laisser le temps à l'animation de
// se terminer avant d'interagir avec ce qu'elle révèle.
Future<void> _laisserRetomber(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // pump(duration) fait avancer l'horloge fake des animations (sinon
    // ExpansionTile ne progresse jamais, quel que soit le nombre de pumps
    // à durée nulle).
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late DatabaseService localDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_budget.db';
  });

  tearDownAll(() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  setUp(() async {
    localDb = DatabaseService();
    final d = await localDb.db;
    await d.delete('articles');
    await d.delete('prix_articles');
    await d.delete('listes');
  });

  testWidgets(
      'ajouter un prix pour un magasin donné le fait apparaître dans la comparaison',
      (tester) async {
    await tester.runAsync(() async {
      await localDb.insertArticle(Article(id: 'art_lait', nom: 'Lait'));
      final sync = SyncService(
        localDb,
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(signedIn: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbServiceProvider.overrideWithValue(localDb),
            syncServiceProvider.overrideWithValue(sync),
          ],
          child: const MaterialApp(home: BudgetScreen()),
        ),
      );
      await _laisserRetomber(tester);

      await tester.ensureVisible(find.text('Lait'));
      await tester.tap(find.text('Lait'));
      await _laisserRetomber(tester);

      await tester.ensureVisible(find.text('Ajouter un prix (magasin)'));
      await tester.tap(find.text('Ajouter un prix (magasin)'));
      await _laisserRetomber(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Carrefour');
      await tester.enterText(find.byType(TextField).at(1), '1.50');
      await tester.tap(find.text('Enregistrer'));
      await _laisserRetomber(tester);

      expect(find.text('Carrefour'), findsOneWidget);
      expect(find.text('1.50 €'), findsOneWidget);

      final prix = await localDb.getPrixArticles();
      expect(prix, hasLength(1));
      expect(prix.first.magasin, 'Carrefour');
      expect(prix.first.prix, 1.5);
    });
  });

  testWidgets(
      'deux prix pour le même article : le moins cher est mis en avant',
      (tester) async {
    await tester.runAsync(() async {
      await localDb.insertArticle(Article(id: 'art_lait', nom: 'Lait'));
      await localDb.setPrixArticle(
          PrixArticle(articleId: 'art_lait', prix: 1.8, magasin: 'Monoprix'));
      await localDb.setPrixArticle(
          PrixArticle(articleId: 'art_lait', prix: 1.2, magasin: 'Lidl'));

      final sync = SyncService(
        localDb,
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(signedIn: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbServiceProvider.overrideWithValue(localDb),
            syncServiceProvider.overrideWithValue(sync),
          ],
          child: const MaterialApp(home: BudgetScreen()),
        ),
      );
      await _laisserRetomber(tester);

      expect(find.text('2 magasins comparés'), findsOneWidget);

      await tester.tap(find.text('Lait'));
      await _laisserRetomber(tester);

      expect(find.text('Lidl'), findsOneWidget);
      expect(find.text('Monoprix'), findsOneWidget);
      // L'icône étoile marque le moins cher (Lidl, 1.20€).
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  testWidgets('supprimer un prix le retire de la comparaison', (tester) async {
    await tester.runAsync(() async {
      await localDb.insertArticle(Article(id: 'art_lait', nom: 'Lait'));
      await localDb.setPrixArticle(
          PrixArticle(articleId: 'art_lait', prix: 1.8, magasin: 'Monoprix'));

      final sync = SyncService(
        localDb,
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(signedIn: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbServiceProvider.overrideWithValue(localDb),
            syncServiceProvider.overrideWithValue(sync),
          ],
          child: const MaterialApp(home: BudgetScreen()),
        ),
      );
      await _laisserRetomber(tester);

      await tester.ensureVisible(find.text('Lait'));
      await tester.tap(find.text('Lait'));
      await _laisserRetomber(tester);
      await tester.ensureVisible(find.text('1.80 €'));
      await tester.tap(find.text('1.80 €'));
      await _laisserRetomber(tester);

      await tester.tap(find.text('Supprimer'));
      await _laisserRetomber(tester);

      final prix = await localDb.getPrixArticles();
      expect(prix, isEmpty);
    });
  });
}
