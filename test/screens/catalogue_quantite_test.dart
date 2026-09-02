// Vérifie que « choisir la quantité » dans le catalogue puis ajouter à une
// liste enregistre bien cette quantité sur la ligne de liste (et ne se limite
// pas à 1). On pré-règle la sélection + la quantité via les providers, puis on
// tape le bouton « Ajouter » de l'écran Catalogue.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartcart/models/models.dart';
import 'package:smartcart/providers/providers.dart';
import 'package:smartcart/screens/catalogue_screen.dart';
import 'package:smartcart/services/database_service.dart';
import 'package:smartcart/services/sync_service.dart';

Future<void> _laisserRetomber(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

void main() {
  late DatabaseService localDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_catalogue_qte.db';
  });

  tearDownAll(() async {
    final path =
        p.join(await getDatabasesPath(), DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  setUp(() async {
    // Le widget d'accueil lit shared_preferences pendant l'ajout : on fournit
    // des valeurs mock pour éviter une MissingPluginException dans les tests.
    SharedPreferences.setMockInitialValues({});
    localDb = DatabaseService();
    final d = await localDb.db;
    await d.delete('listes');
    await d.delete('articles_liste');
    await d.delete('articles');
  });

  testWidgets('la quantité choisie est enregistrée sur la ligne de liste',
      (tester) async {
    await tester.runAsync(() async {
      final liste = ListeCourses(id: 'L1', nom: 'Carrefour');
      await localDb.insertListe(liste);
      await localDb.insertArticle(Article(id: 'A1', nom: 'Lait'));

      final sync = SyncService(
        localDb,
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(signedIn: false),
      );
      final container = ProviderContainer(overrides: [
        dbServiceProvider.overrideWithValue(localDb),
        syncServiceProvider.overrideWithValue(sync),
      ]);
      addTearDown(container.dispose);

      // Pré-règle : liste sélectionnée, article coché, quantité 3.
      container.read(listeSelectionneeProvider.notifier).state = liste;
      container.read(articlesSelectionnesProvider.notifier).state = {'A1'};
      container.read(articlesQuantitesProvider.notifier).state = {'A1': 3};

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CatalogueScreen()),
        ),
      );
      await _laisserRetomber(tester);

      await tester.tap(find.textContaining('Ajouter'));
      await _laisserRetomber(tester);

      final items = await localDb.getArticlesListe('L1');
      expect(items.length, 1);
      expect(items.single.quantite, 3);
    });
  });
}
