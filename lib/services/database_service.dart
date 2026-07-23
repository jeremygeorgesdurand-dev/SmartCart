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
      version: 9,
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
        createdAt TEXT NOT NULL
      )
    ''');

    // Table catégories maison (frigo, placard, etc.)
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        couleur INTEGER NOT NULL,
        ordre INTEGER NOT NULL
      )
    ''');

    // Table rayons magasin (épicerie, surgelés, etc.)
    await db.execute('''
      CREATE TABLE rayons (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        ordre INTEGER NOT NULL,
        magasin TEXT,
        couleur INTEGER DEFAULT 6296528
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
        ingredientsJson TEXT NOT NULL DEFAULT '[]'
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
        FOREIGN KEY (listeId) REFERENCES listes(id) ON DELETE CASCADE,
        FOREIGN KEY (articleId) REFERENCES articles(id)
      )
    ''');

    // Données par défaut : catégories maison
    await _insertDefaultCategories(db);
    // Données par défaut : rayons magasin
    await _insertDefaultRayons(db);
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
  Future<List<Article>> getArticles() async {
    final d = await db;
    final rows = await d.query('articles', orderBy: 'nom ASC');
    return rows.map(Article.fromMap).toList();
  }

  Future<List<Article>> searchArticles(String query) async {
    final d = await db;
    final rows = await d.query(
      'articles',
      where: 'nom LIKE ?',
      whereArgs: ['%$query%'],
    );
    return rows.map(Article.fromMap).toList();
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
    // des lignes orphelines dans les listes qui le référençaient encore.
    await d.delete('articles_liste', where: 'articleId = ?', whereArgs: [id]);
    await d.delete('prix_articles', where: 'articleId = ?', whereArgs: [id]);
    await d.delete('prix_historique', where: 'articleId = ?', whereArgs: [id]);
    await d.delete('prix_cache_web', where: 'articleId = ?', whereArgs: [id]);
    await d.delete('articles', where: 'id = ?', whereArgs: [id]);
  }

  // ─── CATÉGORIES ──────────────────────────────────────────
  Future<List<Categorie>> getCategories() async {
    final d = await db;
    final rows = await d.query('categories', orderBy: 'ordre ASC');
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
      where: magasin != null ? 'magasin = ? OR magasin IS NULL' : null,
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
