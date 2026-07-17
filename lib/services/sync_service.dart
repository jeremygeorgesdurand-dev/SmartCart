import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'database_service.dart';

class SyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseService _localDb;

  SyncService(this._localDb);

  // Référence à la collection de l'utilisateur connecté
  CollectionReference _userCol(String sub) =>
      _db.collection('users').doc(sub).collection(sub);

  CollectionReference _col(String name) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Non connecté');
    return _db.collection('users').doc(uid).collection(name);
  }

  // ── UPLOAD COMPLET (local → Firestore) ─────────────────────────
  Future<void> uploadTout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final articles = await _localDb.getArticles();
    final categories = await _localDb.getCategories();
    final rayons = await _localDb.getRayons();
    final listes = await _localDb.getListes();

    final batch = _db.batch();

    // Supprimer et réécrire (approche simple)
    for (final a in articles) {
      batch.set(_col('articles').doc(a.id), a.toMap());
    }
    for (final c in categories) {
      batch.set(_col('categories').doc(c.id), c.toMap());
    }
    for (final r in rayons) {
      batch.set(_col('rayons').doc(r.id), r.toMap());
    }
    for (final l in listes) {
      batch.set(_col('listes').doc(l.id), l.toMap());
      // Articles de chaque liste
      final items = await _localDb.getArticlesListe(l.id);
      for (final item in items) {
        batch.set(
          _col('listes').doc(l.id).collection('articles').doc(item.id),
          item.toMap(),
        );
      }
    }

    await batch.commit();
  }

  // ── DOWNLOAD COMPLET (Firestore → local) ───────────────────────
  Future<void> downloadTout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Catégories
    final catsSnap = await _col('categories').get();
    for (final doc in catsSnap.docs) {
      final cat = Categorie.fromMap(doc.data() as Map<String, dynamic>);
      try {
        await _localDb.insertCategorie(cat);
      } catch (_) {
        await _localDb.updateCategorie(cat);
      }
    }

    // Rayons
    final rayonsSnap = await _col('rayons').get();
    for (final doc in rayonsSnap.docs) {
      final ray = Rayon.fromMap(doc.data() as Map<String, dynamic>);
      try {
        await _localDb.insertRayon(ray);
      } catch (_) {
        await _localDb.updateRayon(ray);
      }
    }

    // Articles catalogue
    final articlesSnap = await _col('articles').get();
    for (final doc in articlesSnap.docs) {
      final art = Article.fromMap(doc.data() as Map<String, dynamic>);
      try {
        await _localDb.insertArticle(art);
      } catch (_) {
        await _localDb.updateArticle(art);
      }
    }

    // Listes + leurs articles
    final listesSnap = await _col('listes').get();
    for (final doc in listesSnap.docs) {
      final liste = ListeCourses.fromMap(doc.data() as Map<String, dynamic>);
      try {
        await _localDb.insertListe(liste);
      } catch (_) {
        await _localDb.updateListe(liste);
      }

      final itemsSnap = await _col('listes')
          .doc(liste.id)
          .collection('articles')
          .get();
      for (final itemDoc in itemsSnap.docs) {
        final item =
            ArticleListe.fromMap(itemDoc.data());
        try {
          await _localDb.insertArticleListe(item);
        } catch (_) {
          await _localDb.updateArticleListe(item);
        }
      }
    }
  }

  // ── SYNC EN TEMPS RÉEL : écouter les changements Firestore ─────
  Stream<void> ecouterArticles(void Function() onUpdate) {
    return _col('articles').snapshots().map((snap) {
      onUpdate();
    });
  }

  // ── ÉCRITURES INDIVIDUELLES (appelées après chaque modif locale) ─

  Future<void> sauvegarderArticle(Article a) async {
    if (!_estConnecte) return;
    await _col('articles').doc(a.id).set(a.toMap());
  }

  Future<void> supprimerArticle(String id) async {
    if (!_estConnecte) return;
    await _col('articles').doc(id).delete();
  }

  Future<void> sauvegarderCategorie(Categorie c) async {
    if (!_estConnecte) return;
    await _col('categories').doc(c.id).set(c.toMap());
  }

  Future<void> supprimerCategorie(String id) async {
    if (!_estConnecte) return;
    await _col('categories').doc(id).delete();
  }

  Future<void> sauvegarderRayon(Rayon r) async {
    if (!_estConnecte) return;
    await _col('rayons').doc(r.id).set(r.toMap());
  }

  Future<void> supprimerRayon(String id) async {
    if (!_estConnecte) return;
    await _col('rayons').doc(id).delete();
  }

  Future<void> sauvegarderListe(ListeCourses l) async {
    if (!_estConnecte) return;
    await _col('listes').doc(l.id).set(l.toMap());
  }

  Future<void> supprimerListe(String id) async {
    if (!_estConnecte) return;
    await _col('listes').doc(id).delete();
  }

  Future<void> sauvegarderArticleListe(ArticleListe al) async {
    if (!_estConnecte) return;
    await _col('listes')
        .doc(al.listeId)
        .collection('articles')
        .doc(al.id)
        .set(al.toMap());
  }

  Future<void> supprimerArticleListe(String listeId, String id) async {
    if (!_estConnecte) return;
    await _col('listes')
        .doc(listeId)
        .collection('articles')
        .doc(id)
        .delete();
  }

  // ── PRÉFÉRENCES ────────────────────────────────────────────────
  Future<void> sauvegarderPrefs(Map<String, dynamic> prefs) async {
    if (!_estConnecte) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _db.collection('users').doc(uid).set(
          {'prefs': prefs},
          SetOptions(merge: true),
        );
  }

  Future<Map<String, dynamic>?> chargerPrefs() async {
    if (!_estConnecte) return null;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return (doc.data() as Map<String, dynamic>?)?['prefs']
        as Map<String, dynamic>?;
  }

  bool get _estConnecte => FirebaseAuth.instance.currentUser != null;
}
