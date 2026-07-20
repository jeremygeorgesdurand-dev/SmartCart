// Tests d'intégration de SyncService : la logique de synchronisation
// Firestore de l'app, y compris les listes collaboratives (partage via
// code à 6 caractères). Aucun réseau réel ni émulateur Firebase : on
// utilise fake_cloud_firestore (Firestore en mémoire) et
// firebase_auth_mocks (FirebaseAuth en mémoire). La base locale SQLite
// tourne via sqflite_common_ffi (in-process, sans device).
import 'dart:io';
import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/models/models.dart';
import 'package:smartcart/services/database_service.dart';
import 'package:smartcart/services/sync_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockUser userA;
  late MockUser userB;
  late MockFirebaseAuth authA;
  late MockFirebaseAuth authB;
  late DatabaseService localDb;
  late SyncService serviceA;
  late SyncService serviceB;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Fichier dédié : évite les conflits d'accès concurrent avec les autres
    // fichiers de test qui utilisent aussi DatabaseService (singleton).
    DatabaseService.dbFileName = 'smartcart_test_sync.db';
  });

  tearDownAll(() async {
    // Nettoie le fichier sqlite créé par sqflite_common_ffi (écrit dans
    // .dart_tool/, déjà ignoré par git, mais on nettoie proprement).
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  setUp(() async {
    // Nouveau backend Firestore fake à chaque test → isolation complète.
    firestore = FakeFirebaseFirestore();
    userA = MockUser(uid: 'uidA', email: 'alice@test.com', displayName: 'Alice');
    userB = MockUser(uid: 'uidB', email: 'bob@test.com', displayName: 'Bob');
    authA = MockFirebaseAuth(mockUser: userA, signedIn: true);
    authB = MockFirebaseAuth(mockUser: userB, signedIn: true);

    // DatabaseService est un singleton (factory constructor) : la même
    // base sqlite ffi persiste entre les tests du fichier. On la vide
    // avant chaque test pour éviter toute contamination croisée.
    localDb = DatabaseService();
    final d = await localDb.db;
    await d.delete('articles_liste');
    await d.delete('listes');

    serviceA = SyncService(localDb, firestore: firestore, auth: authA);
    serviceB = SyncService(localDb, firestore: firestore, auth: authB);
  });

  group('partagerListe', () {
    test(
        'transforme la liste en liste collaborative : membres, proprietaire, '
        'code, articles migrés et copie perso supprimée', () async {
      final liste = ListeCourses(id: 'liste1', nom: 'Courses', magasin: 'Carrefour');
      await localDb.insertListe(liste);
      final item = ArticleListe(id: 'al1', listeId: 'liste1', articleId: 'art1', quantite: 2);
      await localDb.insertArticleListe(item);

      // Simule une copie personnelle déjà présente côté cloud (uploadée
      // avant le partage) pour vérifier qu'elle est bien nettoyée.
      await firestore
          .collection('users')
          .doc('uidA')
          .collection('listes')
          .doc('liste1')
          .set(liste.toMap());
      await firestore
          .collection('users')
          .doc('uidA')
          .collection('listes')
          .doc('liste1')
          .collection('articles')
          .doc('al1')
          .set(item.toMap());

      final code = await serviceA.partagerListe(liste, [item]);

      expect(code.length, 6);

      final listeDoc = await firestore.collection('listes_partagees').doc('liste1').get();
      expect(listeDoc.exists, isTrue);
      final data = listeDoc.data()!;
      expect(data['membres'], ['uidA']);
      expect(data['proprietaireId'], 'uidA');
      expect(data['nom'], 'Courses');
      expect(data['code'], code);

      final codeDoc = await firestore.collection('codes_partage').doc(code).get();
      expect(codeDoc.exists, isTrue);
      expect(codeDoc.data()!['listeId'], 'liste1');

      final itemsSnap =
          await firestore.collection('listes_partagees').doc('liste1').collection('articles').get();
      expect(itemsSnap.docs.map((d) => d.id), ['al1']);

      // L'ancienne copie personnelle (doc + sous-collection articles) a
      // bien été supprimée.
      final ancienneCopie =
          await firestore.collection('users').doc('uidA').collection('listes').doc('liste1').get();
      expect(ancienneCopie.exists, isFalse);
      final ancienItemsSnap = await firestore
          .collection('users')
          .doc('uidA')
          .collection('listes')
          .doc('liste1')
          .collection('articles')
          .get();
      expect(ancienItemsSnap.docs, isEmpty);
    });

    test('idempotent : une liste déjà partagée renvoie son code existant sans écrire', () async {
      final liste = ListeCourses(id: 'liste2', nom: 'Déjà partagée', partagee: true, code: 'ABCDEF');

      final code = await serviceA.partagerListe(liste, []);

      expect(code, 'ABCDEF');
      // Retour anticipé : aucune écriture Firestore ne doit avoir eu lieu.
      final codeDoc = await firestore.collection('codes_partage').doc('ABCDEF').get();
      expect(codeDoc.exists, isFalse);
      final listeDoc = await firestore.collection('listes_partagees').doc('liste2').get();
      expect(listeDoc.exists, isFalse);
    });

    test('collision de code : le premier code tiré déjà pris est ignoré, un autre est utilisé', () async {
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      const seed = 12345;

      // Reproduit hors service, avec le même seed, la séquence exacte que
      // va produire SyncService._genererCode() (même alphabet, même ordre
      // de tirage) : ceci nous permet de savoir À L'AVANCE quel sera le
      // premier code tiré, puis le second si le premier est en collision.
      final probe = Random(seed);
      final premierCodeAttendu =
          List.generate(6, (_) => alphabet[probe.nextInt(alphabet.length)]).join();
      final deuxiemeCodeAttendu =
          List.generate(6, (_) => alphabet[probe.nextInt(alphabet.length)]).join();
      expect(premierCodeAttendu, isNot(deuxiemeCodeAttendu));

      // On force la collision : le premier code que le service va tirer
      // est déjà présent dans codes_partage.
      await firestore
          .collection('codes_partage')
          .doc(premierCodeAttendu)
          .set({'listeId': 'liste_deja_prise'});

      final serviceDeterministe =
          SyncService(localDb, firestore: firestore, auth: authA, random: Random(seed));
      final liste = ListeCourses(id: 'liste3', nom: 'Collision test');

      final code = await serviceDeterministe.partagerListe(liste, []);

      // Pas de boucle infinie (le test se termine), et le code retenu est
      // bien le deuxième tirage, différent du premier (déjà pris).
      expect(code, deuxiemeCodeAttendu);
      expect(code, isNot(premierCodeAttendu));

      final codeDocPris = await firestore.collection('codes_partage').doc(premierCodeAttendu).get();
      expect(codeDocPris.data()!['listeId'], 'liste_deja_prise'); // inchangé

      final codeDocNouveau = await firestore.collection('codes_partage').doc(code).get();
      expect(codeDocNouveau.data()!['listeId'], 'liste3');
    });
  });

  group('rejoindreListeParCode', () {
    test('code valide : ajoute le membre et retourne la liste + ses articles', () async {
      final liste = ListeCourses(id: 'liste4', nom: 'Courses partagées');
      await localDb.insertListe(liste);
      final item = ArticleListe(id: 'al2', listeId: 'liste4', articleId: 'art2', quantite: 3);
      final code = await serviceA.partagerListe(liste, [item]);

      final result = await serviceB.rejoindreListeParCode(code);

      expect(result, isNotNull);
      expect(result!.liste.id, 'liste4');
      expect(result.liste.partagee, isTrue);
      expect(result.items, hasLength(1));
      expect(result.items.first.id, 'al2');
      expect(result.items.first.quantite, 3);

      final listeDoc = await firestore.collection('listes_partagees').doc('liste4').get();
      expect(
        List<String>.from(listeDoc.data()!['membres'] as List),
        containsAll(['uidA', 'uidB']),
      );
    });

    test('code invalide : retourne null sans effet de bord', () async {
      final avant = await firestore.collection('listes_partagees').get();

      final result = await serviceB.rejoindreListeParCode('ZZZZZZ');

      expect(result, isNull);
      final apres = await firestore.collection('listes_partagees').get();
      expect(apres.docs.length, avant.docs.length);
    });

    test('code normalisé (minuscules + espaces) résout la même liste', () async {
      final liste = ListeCourses(id: 'liste5', nom: 'Courses partagées 2');
      await localDb.insertListe(liste);
      final code = await serviceA.partagerListe(liste, []);

      final result = await serviceB.rejoindreListeParCode('  ${code.toLowerCase()}  ');

      expect(result, isNotNull);
      expect(result!.liste.id, 'liste5');
    });
  });

  group('quitterListePartagee', () {
    test('retire uniquement soi-même ; liste et articles restent pour les autres membres', () async {
      final liste = ListeCourses(id: 'liste6', nom: 'Test quitter');
      await localDb.insertListe(liste);
      final item = ArticleListe(id: 'al3', listeId: 'liste6', articleId: 'art3');
      final code = await serviceA.partagerListe(liste, [item]);
      await serviceB.rejoindreListeParCode(code);

      await serviceB.quitterListePartagee('liste6');

      final listeDoc = await firestore.collection('listes_partagees').doc('liste6').get();
      expect(listeDoc.exists, isTrue);
      expect(List<String>.from(listeDoc.data()!['membres'] as List), ['uidA']);

      final itemsSnap =
          await firestore.collection('listes_partagees').doc('liste6').collection('articles').get();
      expect(itemsSnap.docs.map((d) => d.id), ['al3']);
    });
  });

  group('retirerMembre', () {
    test('un membre peut en retirer un autre (retrait forcé)', () async {
      final liste = ListeCourses(id: 'liste7', nom: 'Test retirer membre');
      await localDb.insertListe(liste);
      final code = await serviceA.partagerListe(liste, []);
      await serviceB.rejoindreListeParCode(code);

      await serviceA.retirerMembre('liste7', 'uidB');

      final listeDoc = await firestore.collection('listes_partagees').doc('liste7').get();
      expect(List<String>.from(listeDoc.data()!['membres'] as List), ['uidA']);
    });
  });

  group('sauvegarderListe / supprimerListe : routage personnel vs collaboratif', () {
    test('liste personnelle : sauvegarde et suppression vont dans users/{uid}/listes', () async {
      final liste = ListeCourses(id: 'listeP1', nom: 'Perso');
      await localDb.insertListe(liste);

      await serviceA.sauvegarderListe(liste);

      final doc = await firestore.collection('users').doc('uidA').collection('listes').doc('listeP1').get();
      expect(doc.exists, isTrue);
      final collabDoc = await firestore.collection('listes_partagees').doc('listeP1').get();
      expect(collabDoc.exists, isFalse);

      await serviceA.supprimerListe('listeP1');

      final docApresSuppression =
          await firestore.collection('users').doc('uidA').collection('listes').doc('listeP1').get();
      expect(docApresSuppression.exists, isFalse);
    });

    test(
        'liste collaborative : sauvegarde met à jour listes_partagees sans toucher '
        'membres/proprietaire, et suppression = quitter (le doc reste pour les autres)', () async {
      final origine = ListeCourses(id: 'listeC1', nom: 'Collab', magasin: 'Leclerc');
      await localDb.insertListe(origine);
      await serviceA.partagerListe(origine, []);
      // Un second membre rejoint, pour vérifier qu'il n'est pas affecté par
      // la suppression de userA plus bas.
      final codeDoc = await firestore.collection('listes_partagees').doc('listeC1').get();
      final code = codeDoc.data()!['code'] as String;
      await serviceB.rejoindreListeParCode(code);

      // La copie locale est maintenant "collaborative" (comme le ferait un
      // download normal), avec un nom modifié.
      final listeLocaleCollab = origine.copyWith(partagee: true, nom: 'Collab modifié');
      await localDb.insertListe(listeLocaleCollab);

      await serviceA.sauvegarderListe(listeLocaleCollab);

      final doc = await firestore.collection('listes_partagees').doc('listeC1').get();
      expect(doc.data()!['nom'], 'Collab modifié');
      expect(doc.data()!['membres'], ['uidA', 'uidB']); // inchangé par sauvegarderListe
      expect(doc.data()!['proprietaireId'], 'uidA'); // inchangé

      await serviceA.supprimerListe('listeC1');

      final docApresSuppression = await firestore.collection('listes_partagees').doc('listeC1').get();
      expect(docApresSuppression.exists, isTrue); // pas supprimé, juste quitté
      expect(List<String>.from(docApresSuppression.data()!['membres'] as List), ['uidB']);
    });
  });

  group('uploadTout', () {
    test('une liste locale partagee=true n\'est pas uploadée dans users/{uid}/listes', () async {
      final listePerso = ListeCourses(id: 'lp1', nom: 'Perso up');
      final listeCollab = ListeCourses(id: 'lc1', nom: 'Collab up', partagee: true, code: 'ZZZZZZ');
      await localDb.insertListe(listePerso);
      await localDb.insertListe(listeCollab);

      await serviceA.uploadTout();

      final persoDoc =
          await firestore.collection('users').doc('uidA').collection('listes').doc('lp1').get();
      expect(persoDoc.exists, isTrue);

      final collabCommePersoDoc =
          await firestore.collection('users').doc('uidA').collection('listes').doc('lc1').get();
      expect(collabCommePersoDoc.exists, isFalse);
    });

    test('supprime les orphelins cloud (liste personnelle effacée localement)', () async {
      // Une liste existe côté cloud personnel mais plus en local : doit
      // être supprimée par le nettoyage des orphelins.
      await firestore
          .collection('users')
          .doc('uidA')
          .collection('listes')
          .doc('orpheline')
          .set({'id': 'orpheline', 'nom': 'Vieille liste'});

      await serviceA.uploadTout();

      final doc =
          await firestore.collection('users').doc('uidA').collection('listes').doc('orpheline').get();
      expect(doc.exists, isFalse);
    });
  });
}
