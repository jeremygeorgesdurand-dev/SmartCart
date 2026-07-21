import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'database_service.dart';

class SyncService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final DatabaseService _localDb;
  final Random _random;

  // firestore/auth/random optionnels : par défaut les singletons Firebase
  // réels et un Random() non-seedé, mais injectables pour les tests
  // (fake_cloud_firestore, firebase_auth_mocks, et un Random(seed) pour
  // rendre déterministe le tirage de code dans _genererCode).
  SyncService(
    this._localDb, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Random? random,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _random = random ?? Random();

  CollectionReference _col(String name) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Non connecté');
    return _db.collection('users').doc(uid).collection(name);
  }

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Non connecté');
    return uid;
  }

  CollectionReference get _listesPartageesCol =>
      _db.collection('listes_partagees');
  CollectionReference get _codesPartageCol =>
      _db.collection('codes_partage');

  // ── UPLOAD COMPLET (local → Firestore) ─────────────────────────
  Future<void> uploadTout() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final articles = await _localDb.getArticles();
    final categories = await _localDb.getCategories();
    final rayons = await _localDb.getRayons();
    // Les listes collaboratives vivent dans listes_partagees, pas ici.
    final listes = (await _localDb.getListes(inclureArchivees: true))
        .where((l) => !l.partagee)
        .toList();
    final prix = await _localDb.getPrixArticles();

    final batch = _db.batch();

    // Supprimer côté cloud ce qui n'existe plus en local (ex: suppression
    // faite avant la dernière connexion, jamais répercutée individuellement)
    await _supprimerOrphelinsCloud(
        batch, 'articles', articles.map((a) => a.id).toSet());
    await _supprimerOrphelinsCloud(
        batch, 'categories', categories.map((c) => c.id).toSet());
    await _supprimerOrphelinsCloud(
        batch, 'rayons', rayons.map((r) => r.id).toSet());
    await _supprimerOrphelinsCloud(
        batch, 'listes', listes.map((l) => l.id).toSet());
    await _supprimerOrphelinsCloud(
        batch, 'prix', prix.map(_prixDocId).toSet());

    for (final a in articles) {
      batch.set(_col('articles').doc(a.id), a.toMap());
    }
    for (final c in categories) {
      batch.set(_col('categories').doc(c.id), c.toMap());
    }
    for (final r in rayons) {
      batch.set(_col('rayons').doc(r.id), r.toMap());
    }
    for (final p in prix) {
      batch.set(_col('prix').doc(_prixDocId(p)), p.toMap());
    }
    for (final l in listes) {
      batch.set(_col('listes').doc(l.id), l.toMap());

      final items = await _localDb.getArticlesListe(l.id);
      final itemsCol = _col('listes').doc(l.id).collection('articles');
      final cloudItemsSnap = await itemsCol.get();
      final idsLocaux = items.map((i) => i.id).toSet();
      for (final doc in cloudItemsSnap.docs) {
        if (!idsLocaux.contains(doc.id)) batch.delete(doc.reference);
      }
      for (final item in items) {
        batch.set(itemsCol.doc(item.id), item.toMap());
      }
    }

    await batch.commit();
  }

  // Supprime dans `batch` les documents de `nomCollection` qui n'existent
  // plus en local (ex: article supprimé sans passer par la synchro
  // individuelle, ou avant la première connexion).
  Future<void> _supprimerOrphelinsCloud(
    WriteBatch batch,
    String nomCollection,
    Set<String> idsLocaux,
  ) async {
    final cloudSnap = await _col(nomCollection).get();
    for (final doc in cloudSnap.docs) {
      if (!idsLocaux.contains(doc.id)) batch.delete(doc.reference);
    }
  }

  // ── DOWNLOAD COMPLET (Firestore → local) ───────────────────────
  Future<void> downloadTout() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Catégories
    final catsSnap = await _col('categories').get();
    for (final doc in catsSnap.docs) {
      try {
        final cat = Categorie.fromMap(doc.data() as Map<String, dynamic>);
        await _localDb.insertCategorie(cat);
      } catch (_) {
        continue; // doc corrompu : on l'ignore sans bloquer le reste
      }
    }

    // Rayons
    final rayonsSnap = await _col('rayons').get();
    for (final doc in rayonsSnap.docs) {
      try {
        final ray = Rayon.fromMap(doc.data() as Map<String, dynamic>);
        await _localDb.insertRayon(ray);
      } catch (_) {
        continue;
      }
    }

    // Articles catalogue
    final articlesSnap = await _col('articles').get();
    for (final doc in articlesSnap.docs) {
      try {
        final art = Article.fromMap(doc.data() as Map<String, dynamic>);
        await _localDb.insertArticle(art);
      } catch (_) {
        continue;
      }
    }

    // Prix estimés
    final prixSnap = await _col('prix').get();
    for (final doc in prixSnap.docs) {
      try {
        final p = PrixArticle.fromMap(doc.data() as Map<String, dynamic>);
        await _localDb.setPrixArticle(p);
      } catch (_) {
        continue;
      }
    }

    // Listes + leurs articles
    final listesSnap = await _col('listes').get();
    for (final doc in listesSnap.docs) {
      ListeCourses liste;
      try {
        liste = ListeCourses.fromMap(doc.data() as Map<String, dynamic>);
        await _localDb.insertListe(liste);
      } catch (_) {
        continue;
      }

      final itemsSnap = await _col('listes')
          .doc(liste.id)
          .collection('articles')
          .get();
      for (final itemDoc in itemsSnap.docs) {
        try {
          final item = ArticleListe.fromMap(itemDoc.data());
          await _localDb.insertArticleListe(item);
        } catch (_) {
          continue;
        }
      }
    }
  }

  // ── SYNC EN TEMPS RÉEL : écouter les changements Firestore ─────
  // Répercute localement les changements faits depuis un autre appareil
  // (ajout/modif/suppression) et prévient l'appelant via onChangement()
  // pour qu'il invalide les providers concernés.
  final Map<String, StreamSubscription> _subs = {};

  void demarrerEcouteTempsReel(void Function() onChangement) {
    arreterEcouteTempsReel();
    if (!_estConnecte) return;

    _ecouterCollection<Categorie>(
      'categories',
      Categorie.fromMap,
      _localDb.insertCategorie,
      _localDb.deleteCategorie,
      onChangement,
    );
    _ecouterCollection<Rayon>(
      'rayons',
      Rayon.fromMap,
      _localDb.insertRayon,
      _localDb.deleteRayon,
      onChangement,
    );
    _ecouterCollection<Article>(
      'articles',
      Article.fromMap,
      _localDb.insertArticle,
      _localDb.deleteArticle,
      onChangement,
    );
    _ecouterCollection<PrixArticle>(
      'prix',
      PrixArticle.fromMap,
      _localDb.setPrixArticle,
      _localDb.deletePrixArticle,
      onChangement,
    );

    // Listes : en plus d'appliquer les changements, on démarre/arrête
    // l'écoute des articles de chaque liste au fil de l'eau.
    _subs['listes'] = _col('listes').snapshots().listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        final listeId = change.doc.id;
        if (change.type == DocumentChangeType.removed) {
          await _localDb.deleteListe(listeId);
          await _subs.remove('liste_articles_$listeId')?.cancel();
          continue;
        }
        try {
          final liste =
              ListeCourses.fromMap(change.doc.data() as Map<String, dynamic>);
          await _localDb.insertListe(liste);
        } catch (_) {
          continue;
        }
        _subs.putIfAbsent('liste_articles_$listeId', () {
          return _col('listes')
              .doc(listeId)
              .collection('articles')
              .snapshots()
              .listen((itemsSnap) async {
            for (final itemChange in itemsSnap.docChanges) {
              if (itemChange.doc.metadata.hasPendingWrites) continue;
              if (itemChange.type == DocumentChangeType.removed) {
                await _localDb.deleteArticleListe(itemChange.doc.id);
              } else {
                try {
                  final item = ArticleListe.fromMap(itemChange.doc.data()!);
                  await _localDb.insertArticleListe(item);
                } catch (_) {
                  continue;
                }
              }
            }
            onChangement();
          });
        });
      }
      onChangement();
    });

    // Listes partagées : toutes celles dont je suis membre (créées par moi
    // ou rejointes via un code). Un retrait des membres fait disparaître
    // le document des résultats de la requête → traité comme suppression.
    _subs['listes_partagees'] = _listesPartageesCol
        .where('membres', arrayContains: _uid)
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        final listeId = change.doc.id;
        if (change.type == DocumentChangeType.removed) {
          await _localDb.deleteListe(listeId);
          await _subs.remove('liste_articles_$listeId')?.cancel();
          continue;
        }
        try {
          final liste =
              ListeCourses.fromMap(change.doc.data() as Map<String, dynamic>)
                  .copyWith(partagee: true);
          await _localDb.insertListe(liste);
        } catch (_) {
          continue;
        }
        _subs.putIfAbsent('liste_articles_$listeId', () {
          return _listesPartageesCol
              .doc(listeId)
              .collection('articles')
              .snapshots()
              .listen((itemsSnap) async {
            for (final itemChange in itemsSnap.docChanges) {
              if (itemChange.doc.metadata.hasPendingWrites) continue;
              if (itemChange.type == DocumentChangeType.removed) {
                await _localDb.deleteArticleListe(itemChange.doc.id);
              } else {
                try {
                  final item = ArticleListe.fromMap(itemChange.doc.data()!);
                  await _localDb.insertArticleListe(item);
                } catch (_) {
                  continue;
                }
              }
            }
            onChangement();
          });
        });
      }
      onChangement();
    });
  }

  void _ecouterCollection<T>(
    String nomCollection,
    T Function(Map<String, dynamic>) fromMap,
    Future<void> Function(T) inserer,
    Future<void> Function(String) supprimer,
    void Function() onChangement,
  ) {
    _subs[nomCollection] =
        _col(nomCollection).snapshots().listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        if (change.type == DocumentChangeType.removed) {
          await supprimer(change.doc.id);
        } else {
          try {
            final item = fromMap(change.doc.data() as Map<String, dynamic>);
            await inserer(item);
          } catch (_) {
            continue;
          }
        }
      }
      onChangement();
    });
  }

  void arreterEcouteTempsReel() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
  }

  // ── COLLABORATION : listes partagées entre plusieurs comptes ───
  // Sans caractères ambigus (I/O/0/1) pour une saisie manuelle facile.
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _genererCode() {
    return List.generate(
        6, (_) => _codeChars[_random.nextInt(_codeChars.length)]).join();
  }

  // Transforme une liste personnelle en liste collaborative et retourne
  // le code à partager (idempotent si déjà partagée).
  Future<String> partagerListe(
      ListeCourses liste, List<ArticleListe> items) async {
    if (liste.partagee && liste.code != null) return liste.code!;

    final uid = _uid;
    String code;
    do {
      code = _genererCode();
    } while ((await _codesPartageCol.doc(code).get()).exists);

    final batch = _db.batch();
    final docRef = _listesPartageesCol.doc(liste.id);
    batch.set(docRef, {
      ...liste.copyWith(partagee: true, code: code).toMap(),
      'membres': [uid],
      'proprietaireId': uid,
    });
    for (final item in items) {
      batch.set(docRef.collection('articles').doc(item.id), item.toMap());
    }
    // Nettoyer l'ancienne copie personnelle (désormais dans listes_partagees)
    final ancienItemsSnap =
        await _col('listes').doc(liste.id).collection('articles').get();
    for (final doc in ancienItemsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_col('listes').doc(liste.id));

    await batch.commit();

    // Créé séparément, APRÈS la validation du batch ci-dessus : la règle
    // Firestore de codes_partage vérifie le proprietaireId via un get()
    // sur listes_partagees/{listeId}. Si ce document était créé dans le
    // même batch, ce get() ne le verrait pas encore (les écritures d'un
    // batch ne sont pas visibles entre elles avant validation complète),
    // et la règle échouerait systématiquement avec "permission denied".
    await _codesPartageCol.doc(code).set({'listeId': liste.id});

    return code;
  }

  // Rejoint une liste collaborative via son code. Retourne la liste et ses
  // articles (à insérer localement), ou null si le code est invalide.
  Future<({ListeCourses liste, List<ArticleListe> items})?>
      rejoindreListeParCode(String code) async {
    final codeDoc = await _codesPartageCol.doc(code.trim().toUpperCase()).get();
    if (!codeDoc.exists) return null;
    final listeId = (codeDoc.data() as Map<String, dynamic>)['listeId'] as String;

    // La règle de lecture de listes_partagees exige d'être déjà dans
    // `membres` : il faut donc s'ajouter D'ABORD (la règle d'update
    // l'autorise explicitement pour un non-membre), puis seulement
    // ensuite lire le document — sinon ce get() échoue systématiquement
    // avec "permission denied" pour quiconque n'est pas encore membre,
    // ce qui est le cas de tout le monde au moment de rejoindre.
    await _listesPartageesCol.doc(listeId).update({
      'membres': FieldValue.arrayUnion([_uid]),
    });

    final listeDoc = await _listesPartageesCol.doc(listeId).get();
    if (!listeDoc.exists) return null;

    final liste = ListeCourses.fromMap(listeDoc.data() as Map<String, dynamic>)
        .copyWith(partagee: true);
    final itemsSnap =
        await _listesPartageesCol.doc(listeId).collection('articles').get();
    final items =
        itemsSnap.docs.map((d) => ArticleListe.fromMap(d.data())).toList();
    return (liste: liste, items: items);
  }

  // Retire l'utilisateur courant des membres (la liste reste pour les
  // autres membres). Idempotent.
  Future<void> quitterListePartagee(String listeId) async {
    if (!_estConnecte) return;
    await _listesPartageesCol.doc(listeId).update({
      'membres': FieldValue.arrayRemove([_uid]),
    });
  }

  // Retire un AUTRE membre d'une liste collaborative. N'importe quel
  // membre peut le faire (pas seulement le propriétaire), cohérent avec
  // le modèle de confiance "petit groupe" des règles Firestore.
  Future<void> retirerMembre(String listeId, String uidARetirer) async {
    if (!_estConnecte) return;
    await _listesPartageesCol.doc(listeId).update({
      'membres': FieldValue.arrayRemove([uidARetirer]),
    });
  }

  // Publie le nom/photo de l'utilisateur courant, visibles des autres
  // membres de ses listes collaboratives. À appeler après connexion.
  Future<void> publierProfil() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('profils_publics').doc(user.uid).set({
      'displayName': user.displayName,
      'photoURL': user.photoURL,
    });
  }

  // Membres d'une liste collaborative, avec leur profil public résolu.
  Future<List<({String uid, String? displayName, String? photoURL, bool estProprietaire})>>
      getMembresListe(String listeId) async {
    final doc = await _listesPartageesCol.doc(listeId).get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;
    final membres = List<String>.from(data['membres'] as List);
    final proprietaireId = data['proprietaireId'] as String?;

    final resultat = <({String uid, String? displayName, String? photoURL, bool estProprietaire})>[];
    for (final uid in membres) {
      final profilDoc =
          await _db.collection('profils_publics').doc(uid).get();
      final profil = profilDoc.data();
      resultat.add((
        uid: uid,
        displayName: profil?['displayName'] as String?,
        photoURL: profil?['photoURL'] as String?,
        estProprietaire: uid == proprietaireId,
      ));
    }
    return resultat;
  }

  // ── NOTIFICATIONS PUSH ───────────────────────────────────────────
  Future<void> enregistrerTokenFcm(String token) async {
    if (!_estConnecte) return;
    await _db.collection('users').doc(_uid).set(
      {'fcmTokens': FieldValue.arrayUnion([token])},
      SetOptions(merge: true),
    );
  }

  Future<void> supprimerTokenFcm(String token) async {
    if (!_estConnecte) return;
    await _db.collection('users').doc(_uid).set(
      {'fcmTokens': FieldValue.arrayRemove([token])},
      SetOptions(merge: true),
    );
  }

  // ── SUPPRESSION DE COMPTE (RGPD) ─────────────────────────────────
  // Supprime toutes les données cloud de l'utilisateur : ses données
  // personnelles (users/{uid} et sous-collections), son profil public,
  // et le retire de toutes les listes collaboratives dont il est membre
  // (sans les supprimer pour les autres membres).
  Future<void> supprimerToutesLesDonneesCloud() async {
    if (!_estConnecte) return;
    final uid = _uid;

    for (final nom in ['articles', 'categories', 'rayons', 'prix']) {
      final snap = await _col(nom).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    final listesSnap = await _col('listes').get();
    for (final listeDoc in listesSnap.docs) {
      final itemsSnap = await listeDoc.reference.collection('articles').get();
      for (final item in itemsSnap.docs) {
        await item.reference.delete();
      }
      await listeDoc.reference.delete();
    }

    final listesPartageesSnap = await _listesPartageesCol
        .where('membres', arrayContains: uid)
        .get();
    for (final doc in listesPartageesSnap.docs) {
      await doc.reference.update({
        'membres': FieldValue.arrayRemove([uid]),
      });
    }

    await _db.collection('profils_publics').doc(uid).delete();
    await _db.collection('users').doc(uid).delete();
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
    if (l.partagee) {
      // Le doc collaboratif existe déjà (créé par partagerListe) : on ne
      // touche jamais membres/proprietaireId/code depuis une simple modif.
      // lastModifiedBy permet à la Cloud Function de notifications de ne
      // pas notifier l'auteur du changement.
      await _listesPartageesCol.doc(l.id).update({
        'nom': l.nom,
        'magasin': l.magasin,
        'archivee': l.archivee ? 1 : 0,
        'lastModifiedBy': _uid,
      });
    } else {
      await _col('listes').doc(l.id).set(l.toMap());
    }
  }

  Future<void> supprimerListe(String id) async {
    if (!_estConnecte) return;
    final liste = await _localDb.getListe(id);
    if (liste?.partagee == true) {
      // Suppression d'une liste collaborative = quitter (les autres
      // membres la conservent).
      await quitterListePartagee(id);
    } else {
      await _col('listes').doc(id).delete();
    }
  }

  Future<void> sauvegarderArticleListe(ArticleListe al) async {
    if (!_estConnecte) return;
    final liste = await _localDb.getListe(al.listeId);
    final col = liste?.partagee == true
        ? _listesPartageesCol.doc(al.listeId).collection('articles')
        : _col('listes').doc(al.listeId).collection('articles');
    final data = liste?.partagee == true
        ? {...al.toMap(), 'lastModifiedBy': _uid}
        : al.toMap();
    await col.doc(al.id).set(data);
  }

  Future<void> supprimerArticleListe(String listeId, String id) async {
    if (!_estConnecte) return;
    await (await _articlesColPourListe(listeId)).doc(id).delete();
  }

  Future<CollectionReference> _articlesColPourListe(String listeId) async {
    final liste = await _localDb.getListe(listeId);
    return liste?.partagee == true
        ? _listesPartageesCol.doc(listeId).collection('articles')
        : _col('listes').doc(listeId).collection('articles');
  }

  Future<void> sauvegarderPrix(PrixArticle p) async {
    if (!_estConnecte) return;
    await _col('prix').doc(_prixDocId(p)).set(p.toMap());
  }

  Future<void> supprimerPrix(String articleId, {String magasin = ''}) async {
    if (!_estConnecte) return;
    await _col('prix')
        .doc(_prixDocId(PrixArticle(articleId: articleId, prix: 0, magasin: magasin)))
        .delete();
  }

  // Doc id composite (articleId, magasin) : un article peut avoir un prix
  // différent selon le magasin.
  String _prixDocId(PrixArticle p) => '${p.articleId}_${p.magasin}';

  // ── PRÉFÉRENCES ────────────────────────────────────────────────
  Future<void> sauvegarderPrefs(Map<String, dynamic> prefs) async {
    if (!_estConnecte) return;
    final uid = _auth.currentUser!.uid;
    await _db.collection('users').doc(uid).set(
          {'prefs': prefs},
          SetOptions(merge: true),
        );
  }

  Future<Map<String, dynamic>?> chargerPrefs() async {
    if (!_estConnecte) return null;
    final uid = _auth.currentUser!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['prefs'] as Map<String, dynamic>?;
  }

  bool get _estConnecte => _auth.currentUser != null;
}
