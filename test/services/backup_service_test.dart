// Vérifie le cycle complet export → restauration de BackupService : ce
// qui sort de exporterVersJson() doit pouvoir être réinjecté par
// restaurer() sans perte, dans une base vierge.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartcart/models/models.dart';
import 'package:smartcart/services/backup_service.dart';
import 'package:smartcart/services/database_service.dart';

void main() {
  late DatabaseService db;
  late BackupService backup;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.dbFileName = 'smartcart_test_backup.db';
  });

  tearDownAll(() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DatabaseService.dbFileName);
    if (await File(path).exists()) {
      await databaseFactory.deleteDatabase(path);
    }
  });

  setUp(() async {
    db = DatabaseService();
    final d = await db.db;
    await d.delete('articles');
    await d.delete('listes');
    await d.delete('articles_liste');
    await d.delete('prix_articles');
    await d.delete('prix_historique');
    await d.delete('recettes');
    backup = BackupService(db);
  });

  test(
      'exporte puis restaure articles, liste, articles_liste, prix, '
      'historique et recettes sans perte', () async {
    final article = Article(id: 'art_1', nom: 'Pommes', marque: 'Bio');
    await db.insertArticle(article);

    final liste = ListeCourses(id: 'liste_1', nom: 'Courses du samedi');
    await db.insertListe(liste);

    final item = ArticleListe(
        id: 'al_1', listeId: liste.id, articleId: article.id, quantite: 3);
    await db.insertArticleListe(item);

    await db.setPrixArticle(
        PrixArticle(articleId: article.id, prix: 2.1, magasin: 'Lidl'));
    await db.ajouterHistoriquePrix(PrixHistorique(
        id: 'hist_1', articleId: article.id, prix: 2.1, magasin: 'Lidl'));
    await db.insertRecette(Recette(
      id: 'recette_1',
      nom: 'Tarte aux pommes',
      ingredients: [IngredientRecette(nom: 'Pommes', quantite: 6)],
    ));

    final json = await backup.exporterVersJson();

    // Base vierge : simule une restauration sur un autre appareil.
    await (await db.db).delete('articles');
    await (await db.db).delete('listes');
    await (await db.db).delete('articles_liste');
    await (await db.db).delete('prix_articles');
    await (await db.db).delete('prix_historique');
    await (await db.db).delete('recettes');

    final resultat = await backup.restaurer(json);

    expect(resultat.articles, 1);
    expect(resultat.listes, 1);
    expect(resultat.articlesListe, 1);
    expect(resultat.prixArticles, 1);
    expect(resultat.prixHistorique, 1);
    expect(resultat.recettes, 1);

    final articlesRestaures = await db.getArticles();
    expect(articlesRestaures.single.nom, 'Pommes');

    final listesRestaurees = await db.getListes(inclureArchivees: true);
    expect(listesRestaurees.single.nom, 'Courses du samedi');

    final itemsRestaures = await db.getArticlesListe(liste.id);
    expect(itemsRestaures.single.quantite, 3);

    final prixRestaures = await db.getPrixArticles();
    expect(prixRestaures.single.magasin, 'Lidl');

    final historiqueRestaure = await db.getHistoriquePrix(article.id);
    expect(historiqueRestaure.single.magasin, 'Lidl');

    final recettesRestaurees = await db.getRecettes();
    expect(recettesRestaurees.single.nom, 'Tarte aux pommes');
    expect(recettesRestaurees.single.ingredients.single.nom, 'Pommes');
  });

  test('rejette un fichier qui n\'est pas une sauvegarde SmartCart', () async {
    expect(
      () => backup.restaurer('{"pas_une_sauvegarde": true}'),
      throwsFormatException,
    );
  });

  test('rejette un JSON invalide', () async {
    expect(() => backup.restaurer('ceci n\'est pas du json'), throwsFormatException);
  });
}
