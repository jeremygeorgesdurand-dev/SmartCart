// Tests widget des deux flux les plus critiques de ListesScreen :
// - créer une liste (flux local, le plus utilisé de l'app)
// - rejoindre une liste collaborative via un code (flux réseau, pas de
//   secours local si ça échoue)
// Pas de vrai réseau : fake_cloud_firestore + firebase_auth_mocks. La base
// locale tourne sur sqflite_common_ffi (in-process, sans device). Les
// futures de sqflite/Firestore fake étant de la vraie I/O asynchrone, on
// pompe via tester.runAsync() + pumps manuels plutôt que pumpAndSettle (qui
// n'avance pas sous l'horloge fake de testWidgets).
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
  late DatabaseService localDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Fichier dédié : évite les conflits d'accès concurrent avec les autres
    // fichiers de test qui utilisent aussi DatabaseService (singleton).
    DatabaseService.dbFileName = 'smartcart_test_listes_screen.db';
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
    await d.delete('listes');
    await d.delete('articles_liste');
  });

  testWidgets('créer une liste depuis le FAB la fait apparaître dans la liste',
      (tester) async {
    await tester.runAsync(() async {
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
          child: const MaterialApp(home: ListesScreen()),
        ),
      );
      await _laisserRetomber(tester);

      await tester.tap(find.text('Nouvelle liste'));
      await _laisserRetomber(tester);

      await tester.enterText(find.byType(TextField), 'Courses du dimanche');
      await tester.tap(find.text('Créer'));
      await _laisserRetomber(tester);

      expect(find.text('Courses du dimanche'), findsOneWidget);
      final listes = await localDb.getListes();
      expect(listes.map((l) => l.nom), contains('Courses du dimanche'));
    });
  });

  testWidgets(
      'rejoindre une liste collaborative avec un code valide l\'ajoute aux listes',
      (tester) async {
    await tester.runAsync(() async {
      final firestore = FakeFirebaseFirestore();
      final proprietaire = MockUser(uid: 'uidProprio', displayName: 'Alice');
      final authProprio =
          MockFirebaseAuth(mockUser: proprietaire, signedIn: true);
      final syncProprio =
          SyncService(localDb, firestore: firestore, auth: authProprio);

      // Le propriétaire crée et partage une liste AVANT que l'invité
      // n'ouvre l'écran (simule une liste déjà partagée par quelqu'un).
      final liste = ListeCourses(id: 'liste1', nom: 'Liste des colocs');
      await localDb.insertListe(liste);
      final code = await syncProprio.partagerListe(liste, []);
      // Nettoyage : l'invité repart d'une base locale vierge.
      await (await localDb.db).delete('listes');

      final invite = MockUser(uid: 'uidInvite', displayName: 'Bob');
      final authInvite = MockFirebaseAuth(mockUser: invite, signedIn: true);
      final syncInvite =
          SyncService(localDb, firestore: firestore, auth: authInvite);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbServiceProvider.overrideWithValue(localDb),
            syncServiceProvider.overrideWithValue(syncInvite),
          ],
          child: const MaterialApp(home: ListesScreen()),
        ),
      );
      await _laisserRetomber(tester);

      await tester.tap(find.byTooltip('Rejoindre une liste'));
      await _laisserRetomber(tester);

      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.text('Rejoindre'));
      await _laisserRetomber(tester);

      expect(find.text('Liste rejointe !'), findsOneWidget);
      expect(find.text('Liste des colocs'), findsOneWidget);
    });
  });

  testWidgets('un code invalide affiche un message d\'erreur, sans planter',
      (tester) async {
    await tester.runAsync(() async {
      final sync = SyncService(
        localDb,
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(signedIn: true),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbServiceProvider.overrideWithValue(localDb),
            syncServiceProvider.overrideWithValue(sync),
          ],
          child: const MaterialApp(home: ListesScreen()),
        ),
      );
      await _laisserRetomber(tester);

      await tester.tap(find.byTooltip('Rejoindre une liste'));
      await _laisserRetomber(tester);

      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.tap(find.text('Rejoindre'));
      await _laisserRetomber(tester);

      expect(find.text('Code invalide ou liste introuvable'), findsOneWidget);
    });
  });
}
