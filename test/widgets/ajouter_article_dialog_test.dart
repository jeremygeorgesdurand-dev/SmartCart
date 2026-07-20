// Test widget du flux d'ajout d'article (le plus utilisé de l'app) :
// remplir le nom, valider, vérifier que l'article atterrit bien dans le
// catalogue local. Pas de réseau réel : SyncService tourne sur
// fake_cloud_firestore avec un utilisateur non connecté (sync no-op),
// et la base locale sur sqflite_common_ffi (in-process, sans device).
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/providers/providers.dart';
import 'package:smartcart/services/database_service.dart';
import 'package:smartcart/services/sync_service.dart';
import 'package:smartcart/widgets/ajouter_article_dialog.dart';

// pumpAndSettle ne fonctionne pas ici : la vraie I/O de sqflite_common_ffi
// (via tester.runAsync) ne fait pas avancer l'horloge fake du test, donc on
// pompe manuellement avec de vraies pauses entre les frames.
Future<void> _laisserRetomber(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

void main() {
  late DatabaseService localDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Fichier dédié : évite les conflits d'accès concurrent avec les autres
    // fichiers de test qui utilisent aussi DatabaseService (singleton).
    DatabaseService.dbFileName = 'smartcart_test_ajouter_article.db';
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
  });

  // sqflite_common_ffi fait de la vraie I/O disque (via un isolate) : sous
  // l'horloge fake de testWidgets, ces futures ne se résolvent jamais tant
  // qu'on ne passe pas par tester.runAsync() pour repasser sur l'event loop
  // réelle.
  Future<void> pomperDialog(WidgetTester tester) async {
    await tester.runAsync(() async {
      final auth = MockFirebaseAuth(signedIn: false);
      final sync =
          SyncService(localDb, firestore: FakeFirebaseFirestore(), auth: auth);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbServiceProvider.overrideWithValue(localDb),
            syncServiceProvider.overrideWithValue(sync),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AjouterArticleDialog()),
          ),
        ),
      );
      await _laisserRetomber(tester);
    });
  }

  testWidgets(
      "saisir un nom et valider ajoute l'article au catalogue local",
      (tester) async {
    await pomperDialog(tester);

    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField).first, 'Pommes');
      await tester.tap(find.text('Enregistrer'));
      await _laisserRetomber(tester);

      final articles = await localDb.getArticles();
      expect(articles.map((a) => a.nom), contains('Pommes'));
    });
  });

  testWidgets('valider sans nom ne crée aucun article', (tester) async {
    await pomperDialog(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Enregistrer'));
      await _laisserRetomber(tester);

      final articles = await localDb.getArticles();
      expect(articles, isEmpty);
    });
  });

  testWidgets('la marque est enregistrée quand elle est renseignée',
      (tester) async {
    await pomperDialog(tester);

    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField).at(0), 'Lait');
      await tester.enterText(find.byType(TextField).at(1), 'Lactel');
      await tester.tap(find.text('Enregistrer'));
      await _laisserRetomber(tester);

      final articles = await localDb.getArticles();
      final lait = articles.where((a) => a.nom == 'Lait').firstOrNull;
      expect(lait, isNotNull);
      expect(lait!.marque, 'Lactel');
    });
  });
}
