// Écran d'une liste épuré : un seul bouton flottant (Mode courses), ajout via
// la barre du bas (catalogue + micro intégrés), quantité toujours visible et
// touchable (plus d'appui long caché).
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/models/models.dart';
import 'package:smartcart/providers/providers.dart';
import 'package:smartcart/screens/listes_screen.dart';
import 'package:smartcart/services/database_service.dart';
import 'package:smartcart/services/sync_service.dart';

Future<void> _laisserRetomber(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

void main() {
  late DatabaseService db;
  final liste = ListeCourses(id: 'liste_epure', nom: 'Courses');

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_detail_epure.db';
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
    await d.delete('listes');
    await d.delete('articles');
    await d.delete('articles_liste');
    await db.insertListe(liste);
    await db.insertArticle(Article(id: 'a_lait', nom: 'Lait'));
    await db.insertArticleListe(ArticleListe(
        id: 'al_lait', listeId: liste.id, articleId: 'a_lait', quantite: 1));
  });

  Widget app() => ProviderScope(
        overrides: [
          dbServiceProvider.overrideWithValue(db),
          syncServiceProvider.overrideWithValue(SyncService(
            db,
            firestore: FakeFirebaseFirestore(),
            auth: MockFirebaseAuth(signedIn: false),
          )),
        ],
        child: MaterialApp(home: DetailListeScreen(liste: liste)),
      );

  testWidgets('un seul bouton flottant : Mode courses', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await _laisserRetomber(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Mode courses'), findsOneWidget);
      expect(find.text('Ajouter des articles'), findsNothing);
    });
  });

  testWidgets('la barre du bas porte le catalogue et le micro', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await _laisserRetomber(tester);

      expect(find.byTooltip('Choisir dans le catalogue'), findsOneWidget);
      expect(find.byTooltip('Ajouter par la voix'), findsOneWidget);
    });
  });

  testWidgets('la quantité est visible sur chaque ligne et ouvre le réglage',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await _laisserRetomber(tester);

      // Même à ×1, le badge est affiché (avant : caché tant que quantité = 1).
      expect(find.text('×1'), findsOneWidget);

      await tester.tap(find.text('×1'));
      await tester.pumpAndSettle();

      expect(find.text('Quantité :'), findsOneWidget);
    });
  });
}
