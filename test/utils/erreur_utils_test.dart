// Teste messageErreurLisible : jamais de message technique à l'écran.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcart/utils/erreur_utils.dart';

void main() {
  test('erreur réseau : message de connexion', () {
    expect(messageErreurLisible(const SocketException('x'), 'Sync'),
        'Pas de connexion internet. Réessaie plus tard.');
  });

  test('accès refusé : explique quoi vérifier', () {
    final m = messageErreurLisible(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        'Rejoindre');
    expect(m, contains('accès refusé'));
  });

  test('erreur inconnue : aucun texte technique, une action à faire', () {
    final m = messageErreurLisible(
        Exception('NullPointer at foo.dart:12'), 'Synchronisation impossible');
    expect(m, 'Synchronisation impossible. Réessaie dans un instant.');
    expect(m, isNot(contains('Exception')));
    expect(m, isNot(contains('foo.dart')));
  });

  test('erreur Firebase inconnue : le message brut n\'est pas affiché', () {
    final m = messageErreurLisible(
        FirebaseException(
            plugin: 'firestore', code: 'weird', message: 'RAW INTERNAL'),
        'Suppression impossible');
    expect(m, isNot(contains('RAW INTERNAL')));
  });

  test('contexte générique « Erreur » : phrase neutre', () {
    expect(messageErreurLisible(Exception('boom'), 'Erreur'),
        'Un problème est survenu. Réessaie dans un instant.');
  });
}
