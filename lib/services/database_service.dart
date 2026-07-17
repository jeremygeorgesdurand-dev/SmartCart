import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smartcart.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          // Ajouter colonne couleur aux rayons existants
          await db.execute(
              'ALTER TABLE rayons ADD COLUMN couleur INTEGER DEFAULT 6296528');
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
        archivee INTEGER DEFAULT 0
      )
    ''');

    // Table prix estimés par article
    await db.execute('''
      CREATE TABLE prix_articles (
        articleId TEXT PRIMARY KEY,
        prix REAL NOT NULL
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
      await db.insert('rayons', {'id': r['id'], 'nom': r['nom'], 'ordre': r['ordre'], 'magasin': r['magasin']});
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
}
