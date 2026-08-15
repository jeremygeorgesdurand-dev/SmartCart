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
          // Rendre une liste collaborative supprime son doc personnel
          // (users/{uid}/listes/{id}) dans le même batch que sa création
          // dans listes_partagees — avec le MÊME id local. Si on supprime
          // aveuglément la ligne locale ici, on efface la version qui vient
          // d'être marquée `partagee` juste avant (ListesNotifier.partager),
          // créant une disparition transitoire jusqu'à ce que l'écouteur
          // listes_partagees la réinsère. On ne supprime donc que si la
          // ligne locale n'est PAS déjà une liste collaborative.
          final locale = await _localDb.getListes();
          final existante = locale.where((l) => l.id == listeId).firstOrNull;
          if (existante == null || !existante.partagee) {
            await _localDb.deleteListe(listeId);
          }
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
                  final data = itemChange.doc.data()!;
                  final item = ArticleListe.fromMap(data);
                  // Le catalogue étant personnel, l'article référencé peut ne
                  // pas exister chez ce membre : on le recrée à partir du nom
                  // dénormalisé stocké dans le document partagé (sinon la
                  // ligne serait là mais sans nom affichable). On ne crée que
                  // s'il manque — ne jamais écraser un article local existant.
                  final nomArticle = data['nomArticle'] as String?;
                  if (nomArticle != null && nomArticle.isNotEmpty) {
                    final catalogue = await _localDb.getArticles();
                    final existe =
                        catalogue.any((a) => a.id == item.articleId);
                    if (!existe) {
                      // Rapproche la catégorie/le rayon reçus (par NOM) de mes
                      // propres catégories/rayons du même nom ; sinon l'article
                      // reste « sans catégorie » chez moi (je n'invente pas une
                      // catégorie qui n'existe pas dans mon organisation).
                      final nomCat = data['categorieNom'] as String?;
                      final nomRayon = data['rayonNom'] as String?;
                      String? catId;
                      String? rayonId;
                      if (nomCat != null) {
                        final cats = await _localDb.getCategories();
                        catId = cats
                            .where((c) =>
                                c.nom.toLowerCase() == nomCat.toLowerCase())
                            .firstOrNull
                            ?.id;
                      }
                      if (nomRayon != null) {
                        final rayons = await _localDb.getRayons();
                        rayonId = rayons
                            .where((r) =>
                                r.nom.toLowerCase() == nomRayon.toLowerCase())
                            .firstOrNull
                            ?.id;
                      }
                      await _localDb.insertArticle(Article(
                        id: item.articleId,
                        nom: nomArticle,
                        categorieId: catId,
                        rayonId: rayonId,
                      ));
                    }
                  }
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
    // Nettoyer l'ancienne copie personnelle (désormais dans listes_partagees)
    final ancienItemsSnap =
        await _col('listes').doc(liste.id).collection('articles').get();
    for (final doc in ancienItemsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_col('listes').doc(liste.id));

    await batch.commit();

    // Les articles (sous-collection de listes_partagees) sont écrits dans
    // un batch SÉPARÉ, après la validation du batch ci-dessus : leur règle
    // Firestore vérifie via get() que l'appelant est membre du document
    // PARENT listes_partagees/{listeId}. Si ce parent était créé dans le
    // même batch que ces écritures, ce get() ne le verrait pas encore (les
    // écritures d'un batch ne sont pas visibles entre elles avant
    // validation complète) → permission denied systématique. Même piège
    // que pour codes_partage juste en dessous, mais raté une première fois
    // ici pour les articles.
    if (items.isNotEmpty) {
      final batchArticles = _db.batch();
      for (final item in items) {
        batchArticles.set(docRef.collection('articles').doc(item.id), item.toMap());
      }
      await batchArticles.commit();
    }

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

  // Supprime ENTIÈREMENT une liste collaborative côté cloud (document,
  // articles, code de partage) — réservé au propriétaire. Sans cela, un
  // propriétaire seul « supprimait » sa liste mais quitterListePartagee la
  // laissait orpheline (membres vides) dans Firestore, et surtout, tant que
  // la suppression du membre n'était pas propagée, le listener temps réel
  // pouvait la réinsérer localement — d'où l'impression qu'elle « revenait »
  // et donc qu'on ne pouvait pas la supprimer.
  Future<void> supprimerListePartageeCompletement(ListeCourses liste) async {
    if (!_estConnecte) return;
    final docRef = _listesPartageesCol.doc(liste.id);
    // Couper l'écoute de la sous-collection pour ne pas réagir à nos propres
    // suppressions pendant qu'on les fait.
    await _subs.remove('liste_articles_${liste.id}')?.cancel();
    final itemsSnap = await docRef.collection('articles').get();
    final batch = _db.batch();
    for (final d in itemsSnap.docs) {
      batch.delete(d.reference);
    }
    if (liste.code != null && liste.code!.isNotEmpty) {
      batch.delete(_codesPartageCol.doc(liste.code!));
    }
    batch.delete(docRef);
    await batch.commit();
  }

  // Ré-pousse vers Firestore tous les articles des listes collaboratives
  // locales. Indispensable pour le « + » du widget d'écran d'accueil : il
  // écrit l'article DIRECTEMENT en base SQLite (code natif, QuickAddActivity)
  // sans passer par la synchro, donc un article ajouté depuis le widget à une
  // liste partagée n'arrivait jamais chez les autres membres. On réconcilie au
  // retour de l'app au premier plan. `set` est idempotent (les écritures en
  // attente sont ignorées par le listener, pas de boucle d'écho).
  Future<void> reconcilierListesPartagees() async {
    if (!_estConnecte) return;
    final listes = await _localDb.getListes(inclureArchivees: true);
    for (final liste in listes.where((l) => l.partagee)) {
      final items = await _localDb.getArticlesListe(liste.id);
      for (final item in items) {
        await sauvegarderArticleListe(item);
      }
    }
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
      // On lit le document TANT QU'ON EST ENCORE MEMBRE (la règle de lecture
      // l'exige) pour savoir si on en est le propriétaire.
      String? proprietaireId;
      try {
        final doc = await _listesPartageesCol.doc(id).get();
        if (doc.exists) {
          proprietaireId =
              (doc.data() as Map<String, dynamic>)['proprietaireId'] as String?;
        }
      } catch (_) {
        // lecture impossible : on retombera sur un simple « quitter ».
      }
      if (proprietaireId == _uid && liste != null) {
        // Propriétaire : suppression complète pour tout le monde. Si les
        // règles Firestore refusent la suppression du document, on retombe
        // au moins sur « quitter » pour que la liste disparaisse chez nous.
        try {
          await supprimerListePartageeCompletement(liste);
        } catch (_) {
          await quitterListePartagee(id);
        }
      } else {
        // Membre non-propriétaire : on quitte, les autres la conservent.
        await quitterListePartagee(id);
      }
    } else {
      await _col('listes').doc(id).delete();
    }
  }

  Future<void> sauvegarderArticleListe(ArticleListe al) async {
    if (!_estConnecte) return;
    final liste = await _localDb.getListe(al.listeId);
    if (liste?.partagee == true) {
      // Une ligne de liste ne référence qu'un `articleId` du catalogue, or le
      // catalogue est PERSONNEL à chaque compte : sans le nom, un membre qui
      // reçoit l'ajout d'un autre n'a aucun Article correspondant en base et
      // la ligne reste invisible chez lui. On dénormalise donc le nom (et la
      // catégorie/rayon quand ils existent) dans le document partagé pour que
      // les autres puissent recréer un article local affichable. Voir la
      // reconstruction dans le listener de listes_partagees.
      final articles = await _localDb.getArticles();
      final article = articles.where((a) => a.id == al.articleId).firstOrNull;
      // Les catégories/rayons sont PROPRES à chaque compte : un id de
      // catégorie n'a aucun sens chez l'autre membre. On envoie donc le NOM
      // de la catégorie/du rayon ; à la réception, chacun le fait correspondre
      // à sa propre catégorie du même nom (voir le listener). Réponse à la
      // question « chacun ses catégories ? » : oui, mais on les rapproche par
      // nom pour que l'article tombe dans la bonne rubrique chez tout le monde.
      String? nomCat;
      String? nomRayon;
      if (article?.categorieId != null) {
        final cats = await _localDb.getCategories();
        nomCat =
            cats.where((c) => c.id == article!.categorieId).firstOrNull?.nom;
      }
      if (article?.rayonId != null) {
        final rayons = await _localDb.getRayons();
        nomRayon =
            rayons.where((r) => r.id == article!.rayonId).firstOrNull?.nom;
      }
      await _listesPartageesCol
          .doc(al.listeId)
          .collection('articles')
          .doc(al.id)
          .set({
        ...al.toMap(),
        'lastModifiedBy': _uid,
        if (article != null) 'nomArticle': article.nom,
        if (nomCat != null) 'categorieNom': nomCat,
        if (nomRayon != null) 'rayonNom': nomRayon,
      });
    } else {
      await _col('listes')
          .doc(al.listeId)
          .collection('articles')
          .doc(al.id)
          .set(al.toMap());
    }
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
