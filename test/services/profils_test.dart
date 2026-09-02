// Vérifie le cœur des profils magasin : activer un profil remplace le jeu de
// rayons (ordre + couleurs) ET réaffecte chaque article à son rayon d'après
// l'instantané du profil, puis revenir au profil précédent rétablit tout.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/models/models.dart';
import 'package:smartcart/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_profils.db';
  });

  tearDownAll(() async {
    final path =
        p.join(await getDatabasesPath(), DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  test('activer un profil échange rayons + affectations, aller-retour OK',
      () async {
    final db = DatabaseService();
    final d = await db.db;
    await d.delete('rayons');
    await d.delete('articles');
    await d.delete('profils');

    // Organisation « magasin A » en direct.
    await db.insertRayon(Rayon(id: 'r1', nom: 'Frais', ordre: 0, couleur: 1));
    await db.insertRayon(Rayon(id: 'r2', nom: 'Épicerie', ordre: 1, couleur: 2));
    await db.insertArticle(Article(id: 'a1', nom: 'Lait', rayonId: 'r1'));

    final snapA = await db.capturerOrganisationActive();
    await db.insertProfil(Profil(id: 'A', nom: 'A', donnees: snapA, actif: true));

    // Profil « magasin B » : un seul rayon, Lait rangé ailleurs.
    final snapB = jsonEncode({
      'rayons': [
        {'nom': 'Surgelés', 'couleur': 3, 'ordre': 0}
      ],
      'assignations': {'Lait': 'Surgelés'}
    });
    await db.insertProfil(Profil(id: 'B', nom: 'B', donnees: snapB));

    // Activer B.
    await db.activerProfil('B');
    var rayons = await db.getRayons();
    expect(rayons.map((r) => r.nom).toList(), ['Surgelés']);
    var a1 = (await db.getArticles()).firstWhere((a) => a.id == 'a1');
    expect(a1.rayonId, rayons.first.id);
    expect((await db.getProfilActif())!.id, 'B');

    // Revenir à A : rayons et affectation d'origine rétablis.
    await db.activerProfil('A');
    rayons = await db.getRayons();
    expect(rayons.map((r) => r.nom).toSet(), {'Frais', 'Épicerie'});
    final fraisId = rayons.firstWhere((r) => r.nom == 'Frais').id;
    a1 = (await db.getArticles()).firstWhere((a) => a.id == 'a1');
    expect(a1.rayonId, fraisId);
    expect((await db.getProfilActif())!.id, 'A');
  });
}
