import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // `flutter test` lance chaque fichier de test dans son propre isolate,
  // mais tous partagent le même fichier sqlite par défaut (chemin fixe) :
  // en exécution parallèle, ça provoque des conflits d'accès entre
  // fichiers de test. Modifiable avant le premier accès à `db` pour que
  // chaque fichier de test utilise son propre fichier.
  @visibleForTesting
  static String dbFileName = 'smartcart.db';

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbFileName);

    return await openDatabase(
      path,
      version: 18,
      onCreate: _onCreate,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          // Ajouter colonne couleur aux rayons existants
          await db.execute(
              'ALTER TABLE rayons ADD COLUMN couleur INTEGER DEFAULT 6296528');
        }
        if (oldV < 3) {
          // Listes collaboratives (partagées entre plusieurs comptes)
          await db.execute(
              'ALTER TABLE listes ADD COLUMN partagee INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE listes ADD COLUMN code TEXT');
        }
        if (oldV < 4) {
          // Prix par magasin (comparaison) : la clé primaire passe de
          // articleId seul à (articleId, magasin). SQLite ne permet pas
          // d'altérer une PRIMARY KEY : on recrée la table.
          await db.execute(
              'ALTER TABLE prix_articles RENAME TO prix_articles_old');
          await db.execute('''
            CREATE TABLE prix_articles (
              articleId TEXT NOT NULL,
              magasin TEXT NOT NULL DEFAULT '',
              prix REAL NOT NULL,
              PRIMARY KEY (articleId, magasin)
            )
          ''');
          await db.execute('''
            INSERT INTO prix_articles (articleId, magasin, prix)
            SELECT articleId, '', prix FROM prix_articles_old
          ''');
          await db.execute('DROP TABLE prix_articles_old');
        }
        if (oldV < 5) {
          await db.execute('''
            CREATE TABLE prix_historique (
              id TEXT PRIMARY KEY,
              articleId TEXT NOT NULL,
              magasin TEXT NOT NULL DEFAULT '',
              prix REAL NOT NULL,
              date TEXT NOT NULL
            )
          ''');
        }
        if (oldV < 6) {
          await db.execute('''
            CREATE TABLE recettes (
              id TEXT PRIMARY KEY,
              nom TEXT NOT NULL,
              portions INTEGER NOT NULL DEFAULT 4,
              ingredientsJson TEXT NOT NULL DEFAULT '[]'
            )
          ''');
        }
        if (oldV < 7) {
          // Couleur par liste (nouveau champ, comme catégories/rayons).
          await db.execute(
              'ALTER TABLE listes ADD COLUMN couleur INTEGER DEFAULT 0xFF1ABC9C');

          // Les rayons par défaut avaient une couleur prévue mais jamais
          // écrite (bug d'insertion) : toutes les installs existantes ont
          // donc la même couleur grise par défaut. On corrige uniquement
          // les rayons par défaut encore à cette valeur (pour ne pas
          // écraser une couleur choisie manuellement par l'utilisateur).
          const couleursParDefaut = {
            'ray_fruits': 0xFF4CAF50,
            'ray_boucherie': 0xFFE53935,
            'ray_frais': 0xFF039BE5,
            'ray_epicerie': 0xFFFF8F00,
            'ray_boissons': 0xFF1565C0,
            'ray_surgeles': 0xFF00ACC1,
            'ray_hygiene': 0xFFAB47BC,
            'ray_menage': 0xFF78909C,
          };
          for (final entry in couleursParDefaut.entries) {
            await db.update(
              'rayons',
              {'couleur': entry.value},
              where: 'id = ? AND couleur = 6296528',
              whereArgs: [entry.key],
            );
          }
        }
        if (oldV < 8) {
          // Cache local du prix indicatif trouvé en ligne (Open Prices) :
          // évite de refaire une recherche réseau à chaque ouverture d'écran
          // pour un article qui n'a pas encore de prix saisi par l'utilisateur.
          await db.execute('''
            CREATE TABLE prix_cache_web (
              articleId TEXT PRIMARY KEY,
              trouve INTEGER NOT NULL,
              magasin TEXT,
              prix REAL,
              devise TEXT,
              date TEXT NOT NULL
            )
          ''');
        }
        if (oldV < 9) {
          // Nettoyage unique des lignes `articles_liste` orphelines : les
          // clés étrangères ne sont pas appliquées par sqflite (pas de
          // PRAGMA foreign_keys = ON), donc avant que deleteArticle() ne
          // supprime en cascade (voir cette méthode plus bas), supprimer un
          // article du catalogue laissait derrière lui des lignes
          // `articles_liste` pointant vers un articleId inexistant. Ces
          // lignes fantômes sont comptées dans le total d'une liste (simple
          // requête SQL) mais invisibles partout où l'app doit d'abord
          // retrouver l'article correspondant dans le catalogue pour
          // l'afficher — d'où un décalage "1 article de plus que ce qui
          // s'affiche" et un "1 restant" après avoir tout coché.
          // Les deux tables existent dans toute base réelle depuis la v1,
          // mais une base de test peut simuler un schéma minimal partiel :
          // on vérifie leur présence avant de migrer, par prudence.
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name IN ('articles', 'articles_liste')");
          if (tables.length == 2) {
            await db.execute('''
              DELETE FROM articles_liste
              WHERE articleId NOT IN (SELECT id FROM articles)
            ''');
          }
        }
        if (oldV < 10) {
          // Purge unique des prix indicatifs mis en cache comme "non
          // trouvés" : la recherche (OpenFoodFactsService/OpenPricesService)
          // traitait jusqu'ici un simple timeout réseau transitoire EXACTEMENT
          // comme "aucun prix", et ce faux négatif restait caché jusqu'à 3h
          // (voir prixIndicatifProvider). Avec le nouveau réessai automatique
          // sur timeout, ces anciennes entrées ne sont plus fiables : on les
          // supprime pour que chaque article ait une nouvelle chance d'être
          // retrouvé, sans attendre l'expiration naturelle du cache.
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name = 'prix_cache_web'");
          if (tables.isNotEmpty) {
            await db.execute('DELETE FROM prix_cache_web WHERE trouve = 0');
          }
        }
        if (oldV < 11) {
          // Étapes de préparation et image pour les recettes (import depuis
          // une URL type Marmiton, qui capture aussi instructions + photo).
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name = 'recettes'");
          if (tables.isNotEmpty) {
            await db.execute(
                "ALTER TABLE recettes ADD COLUMN etapesJson TEXT NOT NULL DEFAULT '[]'");
            await db.execute(
                'ALTER TABLE recettes ADD COLUMN imageUrl TEXT');
          }
        }
        if (oldV < 12) {
          // Instantané de catégorie transporté avec un article dans une liste
          // collaborative (nom + couleur), pour un regroupement identique chez
          // tous les membres sans partager les catalogues.
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name = 'articles_liste'");
          if (tables.isNotEmpty) {
            await db.execute(
                'ALTER TABLE articles_liste ADD COLUMN catNom TEXT');
            await db.execute(
                'ALTER TABLE articles_liste ADD COLUMN catCouleur INTEGER');
          }
        }
        if (oldV < 13) {
          // « Qui a coché/ajouté » : uid du dernier membre à avoir modifié la
          // ligne, pour les listes collaboratives.
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name = 'articles_liste'");
          if (tables.isNotEmpty) {
            await db.execute(
                'ALTER TABLE articles_liste ADD COLUMN modifiePar TEXT');
          }
        }
        if (oldV < 14) {
          // Instantané du rayon magasin transporté avec l'article (comme la
          // catégorie), pour l'imposer aux membres d'une liste collaborative.
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name = 'articles_liste'");
          if (tables.isNotEmpty) {
            await db.execute(
                'ALTER TABLE articles_liste ADD COLUMN rayonNom TEXT');
            await db.execute(
                'ALTER TABLE articles_liste ADD COLUMN rayonCouleur INTEGER');
            await db.execute(
                'ALTER TABLE articles_liste ADD COLUMN rayonOrdre INTEGER');
          }
        }
        if (oldV < 15) {
          // Catalogues SUIVIS (partage temps réel, catalogue séparé) : les
          // articles/catégories/rayons reçus sont stockés dans les mêmes tables
          // mais marqués `source` = id du catalogue suivi. Les lecteurs par
          // défaut ne renvoient que MON catalogue (source IS NULL), donc ces
          // entrées ne polluent ni les listes ni le budget.
          for (final t in ['articles', 'categories', 'rayons']) {
            final exists = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
              [t]);
            if (exists.isNotEmpty) {
              await db.execute('ALTER TABLE $t ADD COLUMN source TEXT');
            }
          }
          await db.execute('''
            CREATE TABLE IF NOT EXISTS catalogues_suivis (
              id TEXT PRIMARY KEY,
              nom TEXT
            )
          ''');
        }
        if (oldV < 16) {
          // Nom de l'article dénormalisé SUR la ligne de liste. Indispensable
          // pour les listes collaboratives : les articles d'une liste partagée
          // ne sont pas dans le catalogue PERSONNEL du membre, donc l'affichage
          // ne pouvait pas retrouver leur nom et masquait la ligne (liste qui
          // paraissait vide alors que le widget comptait bien les articles).
          // Avec le nom porté par la ligne, l'affichage ne dépend plus du
          // catalogue local.
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name = 'articles_liste'");
          if (tables.isNotEmpty) {
            await db.execute(
                'ALTER TABLE articles_liste ADD COLUMN nomArticle TEXT');
            // Backfill : on capture MAINTENANT le nom depuis l'article du
            // catalogue tant qu'il existe encore (pour les listes
            // collaboratives, l'app avait « recréé » ces articles). Sans ce
            // remplissage, ces lignes perdraient leur nom si l'article était
            // nettoyé plus tard, et disparaîtraient de la liste (compteur qui
            // affichait moins que le widget).
            await db.execute('''
              UPDATE articles_liste
              SET nomArticle = (
                SELECT a.nom FROM articles a WHERE a.id = articles_liste.articleId
              )
              WHERE nomArticle IS NULL
                AND EXISTS (
                  SELECT 1 FROM articles a WHERE a.id = articles_liste.articleId
                )
            ''');
          }
        }
        if (oldV < 17) {
          // File d'attente des ajouts faits par le WIDGET d'écran d'accueil à
          // une liste collaborative : le code natif écrit directement en SQLite
          // (sans passer par Firestore), on note donc ici quelles lignes doivent
          // être poussées au retour dans l'app. On NE re-pousse plus JAMAIS la
          // liste entière (cela ressuscitait des articles supprimés par un autre
          // membre et défaisait ses coches).
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sync_ajouts_widget (
              id TEXT PRIMARY KEY,
              listeId TEXT NOT NULL
            )
          ''');
        }
        if (oldV < 18) {
          // Profils magasin : chaque profil a SON jeu de rayons (ordre+couleurs)
          // et SON affectation des articles aux rayons, plus une liste associée.
          // Le profil ACTIF est reflété par les rayons/affectations « en direct ».
          await db.execute('''
            CREATE TABLE IF NOT EXISTS profils (
              id TEXT PRIMARY KEY,
              nom TEXT NOT NULL,
              listeId TEXT,
              donnees TEXT,
              actif INTEGER DEFAULT 0,
              ordre INTEGER DEFAULT 0
            )
          ''');
          // Crée un profil par défaut capturant l'organisation actuelle, pour
          // que rien ne change pour un utilisateur existant.
          final dejaUnProfil = await db.rawQuery(
              'SELECT COUNT(*) AS n FROM profils');
          if ((dejaUnProfil.first['n'] as int) == 0) {
            final donnees = await _capturerOrganisation(db);
            await db.insert('profils', {
              'id': 'profil_defaut',
              'nom': 'Mon magasin',
              'donnees': donnees,
              'actif': 1,
              'ordre': 0,
            });
          }
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table articles (catalogue global)
    await db.execute('''
      CREATE TABLE articles (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        categorieId TEXT,
        rayonId TEXT,
        barcode TEXT,
        marque TEXT,
        imageUrl TEXT,
        createdAt TEXT NOT NULL,
        source TEXT
      )
    ''');

    // Table catégories maison (frigo, placard, etc.)
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        couleur INTEGER NOT NULL,
        ordre INTEGER NOT NULL,
        source TEXT
      )
    ''');

    // Table rayons magasin (épicerie, surgelés, etc.)
    await db.execute('''
      CREATE TABLE rayons (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        ordre INTEGER NOT NULL,
        magasin TEXT,
        couleur INTEGER DEFAULT 6296528,
        source TEXT
      )
    ''');

    // Catalogues suivis (partage temps réel, catalogue séparé) : id + nom.
    await db.execute('''
      CREATE TABLE catalogues_suivis (
        id TEXT PRIMARY KEY,
        nom TEXT
      )
    ''');

    // Table listes de courses
    await db.execute('''
      CREATE TABLE listes (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        magasin TEXT,
        archivee INTEGER DEFAULT 0,
        partagee INTEGER DEFAULT 0,
        code TEXT,
        couleur INTEGER DEFAULT 4279942300
      )
    ''');

    // Table prix estimés par article, un prix possible par magasin
    // ('' = pas de magasin précisé)
    await db.execute('''
      CREATE TABLE prix_articles (
        articleId TEXT NOT NULL,
        magasin TEXT NOT NULL DEFAULT '',
        prix REAL NOT NULL,
        PRIMARY KEY (articleId, magasin)
      )
    ''');

    // Historique des prix saisis dans le temps (local uniquement)
    await db.execute('''
      CREATE TABLE prix_historique (
        id TEXT PRIMARY KEY,
        articleId TEXT NOT NULL,
        magasin TEXT NOT NULL DEFAULT '',
        prix REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    // Recettes (local uniquement, pas synchronisé au cloud)
    await db.execute('''
      CREATE TABLE recettes (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        portions INTEGER NOT NULL DEFAULT 4,
        ingredientsJson TEXT NOT NULL DEFAULT '[]',
        etapesJson TEXT NOT NULL DEFAULT '[]',
        imageUrl TEXT
      )
    ''');

    // Cache local du prix indicatif trouvé en ligne (Open Prices)
    await db.execute('''
      CREATE TABLE prix_cache_web (
        articleId TEXT PRIMARY KEY,
        trouve INTEGER NOT NULL,
        magasin TEXT,
        prix REAL,
        devise TEXT,
        date TEXT NOT NULL
      )
    ''');

    // Table articles dans une liste
    await db.execute('''
      CREATE TABLE articles_liste (
        id TEXT PRIMARY KEY,
        listeId TEXT NOT NULL,
        articleId TEXT NOT NULL,
        quantite INTEGER DEFAULT 1,
        unite TEXT,
        note TEXT,
        coche INTEGER DEFAULT 0,
        catNom TEXT,
        catCouleur INTEGER,
        rayonNom TEXT,
        rayonCouleur INTEGER,
        rayonOrdre INTEGER,
        modifiePar TEXT,
        nomArticle TEXT,
        FOREIGN KEY (listeId) REFERENCES listes(id) ON DELETE CASCADE,
        FOREIGN KEY (articleId) REFERENCES articles(id)
      )
    ''');

    // File d'attente des ajouts faits par le widget à une liste collaborative
    // (poussés vers Firestore au retour dans l'app).
    await db.execute('''
      CREATE TABLE sync_ajouts_widget (
        id TEXT PRIMARY KEY,
        listeId TEXT NOT NULL
      )
    ''');

    // Profils magasin (voir migration v18).
    await db.execute('''
      CREATE TABLE profils (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        listeId TEXT,
        donnees TEXT,
        actif INTEGER DEFAULT 0,
        ordre INTEGER DEFAULT 0
      )
    ''');

    // Données par défaut : catégories maison
    await _insertDefaultCategories(db);
    // Données par défaut : rayons magasin
    await _insertDefaultRayons(db);
    // Profil magasin par défaut, capturant l'organisation initiale.
    await db.insert('profils', {
      'id': 'profil_defaut',
      'nom': 'Mon magasin',
      'donnees': await _capturerOrganisation(db),
      'actif': 1,
      'ordre': 0,
    });
  }

  // Instantané JSON de l'organisation « en direct » (rayons perso + affectation
  // article→rayon par NOM). Sert à capturer/rétablir un profil magasin.
  static Future<String> _capturerOrganisation(Database db) async {
    final rayons = await db.query('rayons',
        where: 'source IS NULL', orderBy: 'ordre ASC');
    final articles =
        await db.query('articles', where: 'source IS NULL');
    final rayonNomParId = {
      for (final r in rayons) r['id'] as String: r['nom'] as String
    };
    final assignations = <String, String>{};
    for (final a in articles) {
      final rid = a['rayonId'] as String?;
      if (rid == null) continue;
      final rnom = rayonNomParId[rid];
      if (rnom == null) continue;
      assignations[a['nom'] as String] = rnom;
    }
    return jsonEncode({
      'rayons': [
        for (final r in rayons)
          {
            'nom': r['nom'],
            'couleur': r['couleur'],
            'ordre': r['ordre'],
          }
      ],
      'assignations': assignations,
    });
  }

  Future<void> _insertDefaultCategories(Database db) async {
    const defaultCategories = [
      {'id': 'cat_frigo', 'nom': 'Frigo', 'couleur': 0xFF2196F3, 'ordre': 0},
      {'id': 'cat_congelateur', 'nom': 'Congélateur', 'couleur': 0xFF03A9F4, 'ordre': 1},
      {'id': 'cat_placards', 'nom': 'Placards', 'couleur': 0xFF8BC34A, 'ordre': 2},
      {'id': 'cat_cave', 'nom': 'Cave', 'couleur': 0xFF9C27B0, 'ordre': 3},
      {'id': 'cat_hygiene', 'nom': 'Hygiène', 'couleur': 0xFFFF9800, 'ordre': 4},
      {'id': 'cat_menage', 'nom': 'Ménage', 'couleur': 0xFF607D8B, 'ordre': 5},
    ];
    for (final c in defaultCategories) {
      await db.insert('categories', c);
    }
  }

  Future<void> _insertDefaultRayons(Database db) async {
    const defaultRayons = [
      {'id': 'ray_fruits', 'nom': 'Fruits & Légumes', 'ordre': 0, 'magasin': null, 'couleur': 0xFF4CAF50},
      {'id': 'ray_boucherie', 'nom': 'Boucherie / Poissonnerie', 'ordre': 1, 'magasin': null, 'couleur': 0xFFE53935},
      {'id': 'ray_frais', 'nom': 'Produits frais', 'ordre': 2, 'magasin': null, 'couleur': 0xFF039BE5},
      {'id': 'ray_epicerie', 'nom': 'Épicerie', 'ordre': 3, 'magasin': null, 'couleur': 0xFFFF8F00},
      {'id': 'ray_boissons', 'nom': 'Boissons', 'ordre': 4, 'magasin': null, 'couleur': 0xFF1565C0},
      {'id': 'ray_surgeles', 'nom': 'Surgelés', 'ordre': 5, 'magasin': null, 'couleur': 0xFF00ACC1},
      {'id': 'ray_hygiene', 'nom': 'Hygiène / Beauté', 'ordre': 6, 'magasin': null, 'couleur': 0xFFAB47BC},
      {'id': 'ray_menage', 'nom': 'Entretien', 'ordre': 7, 'magasin': null, 'couleur': 0xFF78909C},
    ];
    for (final r in defaultRayons) {
      await db.insert('rayons', {
        'id': r['id'],
        'nom': r['nom'],
        'ordre': r['ordre'],
        'magasin': r['magasin'],
        'couleur': r['couleur'],
      });
    }
  }

  // ─── ARTICLES ────────────────────────────────────────────
  // MON catalogue uniquement (source IS NULL). Les catalogues SUIVIS sont
  // stockés dans les mêmes tables avec source = id du catalogue, et lus par
  // getArticlesParSource — jamais renvoyés ici, donc ils ne polluent pas les
  // listes, le budget, etc.
  Future<List<Article>> getArticles() async {
    final d = await db;
    final rows =
        await d.query('articles', where: 'source IS NULL', orderBy: 'nom ASC');
    return rows.map(Article.fromMap).toList();
  }

  Future<List<Article>> searchArticles(String query) async {
    final d = await db;
    final rows = await d.query(
      'articles',
      where: 'nom LIKE ? AND source IS NULL',
      whereArgs: ['%$query%'],
    );
    return rows.map(Article.fromMap).toList();
  }

  // ─── CATALOGUES SUIVIS (catalogue séparé, partage temps réel) ────
  Future<List<Article>> getArticlesParSource(String source) async {
    final d = await db;
    final rows = await d.query('articles',
        where: 'source = ?', whereArgs: [source], orderBy: 'nom ASC');
    return rows.map(Article.fromMap).toList();
  }

  Future<List<Categorie>> getCategoriesParSource(String source) async {
    final d = await db;
    final rows = await d.query('categories',
        where: 'source = ?', whereArgs: [source], orderBy: 'ordre ASC');
    return rows.map(Categorie.fromMap).toList();
  }

  Future<List<Rayon>> getRayonsParSource(String source) async {
    final d = await db;
    final rows = await d.query('rayons',
        where: 'source = ?', whereArgs: [source], orderBy: 'ordre ASC');
    return rows.map(Rayon.fromMap).toList();
  }

  // Remplace le contenu local d'un catalogue suivi par celui reçu.
  Future<void> remplacerCatalogueSuivi(
    String source, {
    required List<Article> articles,
    required List<Categorie> categories,
    required List<Rayon> rayons,
    required String nom,
  }) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('articles', where: 'source = ?', whereArgs: [source]);
      await txn.delete('categories', where: 'source = ?', whereArgs: [source]);
      await txn.delete('rayons', where: 'source = ?', whereArgs: [source]);
      for (final a in articles) {
        await txn.insert('articles', {...a.toMap(), 'source': source},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final c in categories) {
        await txn.insert('categories', {...c.toMap(), 'source': source},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final r in rayons) {
        await txn.insert('rayons', {...r.toMap(), 'source': source},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('catalogues_suivis', {'id': source, 'nom': nom},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> supprimerCatalogueSuivi(String source) async {
    final d = await db;
    await d.delete('articles', where: 'source = ?', whereArgs: [source]);
    await d.delete('categories', where: 'source = ?', whereArgs: [source]);
    await d.delete('rayons', where: 'source = ?', whereArgs: [source]);
    await d.delete('catalogues_suivis', where: 'id = ?', whereArgs: [source]);
  }

  Future<List<({String id, String nom})>> getCataloguesSuivis() async {
    final d = await db;
    final rows = await d.query('catalogues_suivis', orderBy: 'nom ASC');
    return rows
        .map((r) =>
            (id: r['id'] as String, nom: (r['nom'] as String?) ?? 'Catalogue'))
        .toList();
  }

  Future<void> insertArticle(Article article) async {
    final d = await db;
    await d.insert('articles', article.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateArticle(Article article) async {
    final d = await db;
    await d.update('articles', article.toMap(),
        where: 'id = ?', whereArgs: [article.id]);
  }

  Future<void> deleteArticle(String id) async {
    final d = await db;
    // articles_liste n'a pas de ON DELETE CASCADE sur articleId (seulement
    // listeId) : sans ce nettoyage explicite, supprimer un article laisse
    // des lignes orphelines dans les listes PERSONNELLES qui le référençaient.
    // ATTENTION : on NE touche PAS aux lignes des listes COLLABORATIVES. Leurs
    // articles ne sont pas dans le catalogue du membre (elles portent leur
    // propre nom dénormalisé) ; un même articleId « recréé » a pu être nettoyé
    // comme orphelin sur un autre appareil, ce qui, en cascade, vidait la liste
    // collaborative (compteur qui tombait à 0, listes dupliquées « liées »).
    // Les suppressions d'articles d'une liste partagée passent par Firestore.
    await d.rawDelete(
      'DELETE FROM articles_liste WHERE articleId = ? AND listeId IN '
      '(SELECT id FROM listes WHERE partagee = 0)',
      [id],
    );
    await d.delete('prix_articles', where: 'articleId = ?', whereArgs: [id]);
    await d.delete('prix_historique', where: 'articleId = ?', whereArgs: [id]);
    await d.delete('prix_cache_web', where: 'articleId = ?', whereArgs: [id]);
    await d.delete('articles', where: 'id = ?', whereArgs: [id]);
  }

  // ─── CATÉGORIES ──────────────────────────────────────────
  Future<List<Categorie>> getCategories() async {
    final d = await db;
    final rows = await d.query('categories',
        where: 'source IS NULL', orderBy: 'ordre ASC');
    return rows.map(Categorie.fromMap).toList();
  }

  Future<void> insertCategorie(Categorie c) async {
    final d = await db;
    await d.insert('categories', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCategorie(Categorie c) async {
    final d = await db;
    await d.update('categories', c.toMap(),
        where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCategorie(String id) async {
    final d = await db;
    await d.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ─── RAYONS ──────────────────────────────────────────────
  Future<List<Rayon>> getRayons({String? magasin}) async {
    final d = await db;
    final rows = await d.query(
      'rayons',
      where: magasin != null
          ? '(magasin = ? OR magasin IS NULL) AND source IS NULL'
          : 'source IS NULL',
      whereArgs: magasin != null ? [magasin] : null,
      orderBy: 'ordre ASC',
    );
    return rows.map(Rayon.fromMap).toList();
  }

  Future<void> insertRayon(Rayon r) async {
    final d = await db;
    await d.insert('rayons', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRayon(Rayon r) async {
    final d = await db;
    await d.update('rayons', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteRayon(String id) async {
    final d = await db;
    await d.delete('rayons', where: 'id = ?', whereArgs: [id]);
  }

  // ─── PROFILS MAGASIN ─────────────────────────────────────
  Future<List<Profil>> getProfils() async {
    final d = await db;
    final rows = await d.query('profils', orderBy: 'ordre ASC, nom ASC');
    return rows.map(Profil.fromMap).toList();
  }

  Future<Profil?> getProfilActif() async {
    final d = await db;
    final rows = await d.query('profils', where: 'actif = 1', limit: 1);
    if (rows.isEmpty) return null;
    return Profil.fromMap(rows.first);
  }

  Future<void> insertProfil(Profil p) async {
    final d = await db;
    await d.insert('profils', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProfil(Profil p) async {
    final d = await db;
    await d.update('profils', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> deleteProfil(String id) async {
    final d = await db;
    await d.delete('profils', where: 'id = ?', whereArgs: [id]);
  }

  // Instantané JSON de l'organisation « en direct » (public).
  Future<String> capturerOrganisationActive() async {
    final d = await db;
    return _capturerOrganisation(d);
  }

  // Rétablit dans l'organisation « en direct » un instantané de profil :
  // remplace le jeu de rayons perso (nouveaux ids) et réaffecte chaque article
  // à son rayon d'après l'instantané (rapproché par NOM). Ne touche jamais aux
  // catalogues suivis (source non NULL).
  Future<void> appliquerDonneesProfil(String? donnees) async {
    final d = await db;
    final data = (donnees == null || donnees.isEmpty)
        ? <String, dynamic>{}
        : jsonDecode(donnees) as Map<String, dynamic>;
    final rayonsSnap =
        (data['rayons'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final assignations =
        (data['assignations'] as Map?)?.cast<String, dynamic>() ?? {};

    await d.transaction((txn) async {
      // 1) Remplace les rayons perso.
      await txn.delete('rayons', where: 'source IS NULL');
      final nomRayonVersId = <String, String>{};
      for (var i = 0; i < rayonsSnap.length; i++) {
        final r = rayonsSnap[i];
        final id = 'rayon_${DateTime.now().microsecondsSinceEpoch}_$i';
        nomRayonVersId[(r['nom'] as String).toLowerCase()] = id;
        await txn.insert('rayons', {
          'id': id,
          'nom': r['nom'],
          'ordre': r['ordre'] ?? i,
          'couleur': r['couleur'] ?? 6296528,
        });
      }
      // 2) Réaffecte les articles perso par nom.
      final articles =
          await txn.query('articles', where: 'source IS NULL');
      for (final a in articles) {
        final nom = a['nom'] as String;
        final rnom = assignations[nom] as String?;
        final nouvelId =
            rnom == null ? null : nomRayonVersId[rnom.toLowerCase()];
        await txn.update('articles', {'rayonId': nouvelId},
            where: 'id = ?', whereArgs: [a['id']]);
      }
    });
  }

  // Change de profil actif : sauvegarde l'organisation courante dans le profil
  // actif, puis charge l'instantané du profil cible et le rend actif.
  Future<void> activerProfil(String id) async {
    final d = await db;
    final actuel = await getProfilActif();
    if (actuel != null && actuel.id != id) {
      final snap = await _capturerOrganisation(d);
      await d.update('profils', {'donnees': snap},
          where: 'id = ?', whereArgs: [actuel.id]);
    }
    final cibleRows =
        await d.query('profils', where: 'id = ?', whereArgs: [id], limit: 1);
    if (cibleRows.isEmpty) return;
    final cible = Profil.fromMap(cibleRows.first);
    await appliquerDonneesProfil(cible.donnees);
    await d.update('profils', {'actif': 0});
    await d.update('profils', {'actif': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // ─── LISTES DE COURSES ───────────────────────────────────
  Future<List<ListeCourses>> getListes({bool inclureArchivees = false}) async {
    final d = await db;
    final rows = await d.query(
      'listes',
      where: inclureArchivees ? null : 'archivee = 0',
      orderBy: 'createdAt DESC',
    );
    return rows.map(ListeCourses.fromMap).toList();
  }

  Future<ListeCourses?> getListe(String id) async {
    final d = await db;
    final rows = await d.query('listes', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ListeCourses.fromMap(rows.first);
  }

  Future<void> insertListe(ListeCourses liste) async {
    final d = await db;
    await d.insert('listes', liste.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateListe(ListeCourses liste) async {
    final d = await db;
    await d.update('listes', liste.toMap(),
        where: 'id = ?', whereArgs: [liste.id]);
  }

  Future<void> deleteListe(String id) async {
    final d = await db;
    await d.delete('listes', where: 'id = ?', whereArgs: [id]);
  }

  Future<ListeCourses?> dupliquerListe(ListeCourses source, String nouveauNom) async {
    final d = await db;
    final nouvelleId = 'liste_${DateTime.now().millisecondsSinceEpoch}';
    final nouvelle = ListeCourses(
      id: nouvelleId,
      nom: nouveauNom,
      magasin: source.magasin,
    );
    await d.insert('listes', nouvelle.toMap());

    // Copier les articles
    final articlesSource = await getArticlesListe(source.id);
    for (final al in articlesSource) {
      await d.insert('articles_liste', {
        ...al.toMap(),
        'id': 'al_${DateTime.now().millisecondsSinceEpoch}_${al.articleId}',
        'listeId': nouvelleId,
        'coche': 0,
      });
    }
    return nouvelle;
  }

  // Recherche globale : articles présents dans une liste (non archivée)
  // dont le nom correspond, avec le nom de la liste et de l'article joints.
  Future<List<Map<String, dynamic>>> rechercherArticlesDansListes(
      String query) async {
    final d = await db;
    return d.rawQuery('''
      SELECT al.*, a.nom AS articleNom, l.nom AS listeNom
      FROM articles_liste al
      JOIN articles a ON a.id = al.articleId
      JOIN listes l ON l.id = al.listeId
      WHERE a.nom LIKE ? AND l.archivee = 0
      ORDER BY l.nom, a.nom
    ''', ['%$query%']);
  }

  // ─── ARTICLES DANS UNE LISTE ─────────────────────────────
  Future<List<ArticleListe>> getArticlesListe(String listeId) async {
    final d = await db;
    final rows = await d.query(
      'articles_liste',
      where: 'listeId = ?',
      whereArgs: [listeId],
    );
    return rows.map(ArticleListe.fromMap).toList();
  }

  Future<void> insertArticleListe(ArticleListe al) async {
    final d = await db;
    await d.insert('articles_liste', al.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── FILE D'ATTENTE DES AJOUTS WIDGET (listes collaboratives) ───────
  // Lignes ajoutées par le widget natif à une liste collaborative, à pousser
  // vers Firestore au retour dans l'app (le natif ne peut pas écrire au cloud).
  Future<List<({String id, String listeId})>> getAjoutsWidget() async {
    final d = await db;
    final rows = await d.query('sync_ajouts_widget');
    return rows
        .map((r) =>
            (id: r['id'] as String, listeId: r['listeId'] as String))
        .toList();
  }

  Future<void> supprimerAjoutWidget(String id) async {
    final d = await db;
    await d.delete('sync_ajouts_widget', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateArticleListe(ArticleListe al) async {
    final d = await db;
    await d.update('articles_liste', al.toMap(),
        where: 'id = ?', whereArgs: [al.id]);
  }

  Future<void> deleteArticleListe(String id) async {
    final d = await db;
    await d.delete('articles_liste', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cocherTous(String listeId, bool coche) async {
    final d = await db;
    await d.update(
      'articles_liste',
      {'coche': coche ? 1 : 0},
      where: 'listeId = ?',
      whereArgs: [listeId],
    );
  }

  // ─── PRIX ARTICLES ────────────────────────────────────────
  Future<List<PrixArticle>> getPrixArticles() async {
    final d = await db;
    final rows = await d.query('prix_articles');
    return rows.map(PrixArticle.fromMap).toList();
  }

  Future<void> setPrixArticle(PrixArticle p) async {
    final d = await db;
    await d.insert('prix_articles', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePrixArticle(String articleId, {String magasin = ''}) async {
    final d = await db;
    await d.delete('prix_articles',
        where: 'articleId = ? AND magasin = ?', whereArgs: [articleId, magasin]);
  }

  // ─── CACHE PRIX WEB (Open Prices) ─────────────────────────
  Future<Map<String, Object?>?> getPrixCacheWeb(String articleId) async {
    final d = await db;
    final rows = await d.query('prix_cache_web',
        where: 'articleId = ?', whereArgs: [articleId], limit: 1);
    return rows.firstOrNull;
  }

  Future<void> setPrixCacheWeb(
    String articleId, {
    required bool trouve,
    String? magasin,
    double? prix,
    String? devise,
  }) async {
    final d = await db;
    await d.insert(
      'prix_cache_web',
      {
        'articleId': articleId,
        'trouve': trouve ? 1 : 0,
        'magasin': magasin,
        'prix': prix,
        'devise': devise,
        'date': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── HISTORIQUE DES PRIX ──────────────────────────────────
  Future<void> ajouterHistoriquePrix(PrixHistorique h) async {
    final d = await db;
    // replace (pas juste insert) : rend une restauration de sauvegarde
    // idempotente si on l'importe deux fois (même id → même entrée).
    await d.insert('prix_historique', h.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PrixHistorique>> getHistoriquePrix(String articleId) async {
    final d = await db;
    final rows = await d.query(
      'prix_historique',
      where: 'articleId = ?',
      whereArgs: [articleId],
      orderBy: 'date ASC',
    );
    return rows.map(PrixHistorique.fromMap).toList();
  }

  // ─── RECETTES ─────────────────────────────────────────────
  Future<List<Recette>> getRecettes() async {
    final d = await db;
    final rows = await d.query('recettes', orderBy: 'nom COLLATE NOCASE');
    return rows.map(Recette.fromMap).toList();
  }

  Future<void> insertRecette(Recette r) async {
    final d = await db;
    await d.insert('recettes', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRecette(String id) async {
    final d = await db;
    await d.delete('recettes', where: 'id = ?', whereArgs: [id]);
  }
}
