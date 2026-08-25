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
  // Catalogues partagés en temps réel (sens unique) : le doc {catalogueId} vaut
  // l'uid du propriétaire ; ses sous-collections categories/rayons/articles
  // sont poussées par lui et lues (fusionnées) par les membres.
  CollectionReference get _cataloguesPartagesCol =>
      _db.collection('catalogues_partages');
  CollectionReference get _codesCatalogueCol =>
      _db.collection('codes_catalogue');

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
        // Suis-je le PROPRIÉTAIRE de cette liste ? Si oui, c'est MOI qui fais
        // autorité sur les catégories : chaque article ajouté par un membre
        // est re-tamponné avec MA catégorie (voir _imposerCategorieProprietaire).
        final estProprio =
            (change.doc.data() as Map<String, dynamic>)['proprietaireId'] ==
                _uid;
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
                  var item = ArticleListe.fromMap(data);
                  // Autorité du propriétaire : j'impose ma catégorie à l'article
                  // si je l'ai à mon catalogue (sinon on garde celle de qui l'a
                  // ajouté). Le re-tampon met à jour Firestore pour les autres
                  // membres, ET on l'applique à ma copie locale (je ne reverrais
                  // jamais ma propre écriture Firestore autrement).
                  if (estProprio) {
                    final corr = await _imposerCategorieProprietaire(
                        listeId, itemChange.doc.id, data);
                    if (corr != null) {
                      item = ArticleListe(
                        id: item.id,
                        listeId: item.listeId,
                        articleId: item.articleId,
                        quantite: item.quantite,
                        unite: item.unite,
                        note: item.note,
                        coche: item.coche,
                        // On n'écrase que ce que le propriétaire impose
                        // réellement ; sinon on garde la valeur reçue.
                        catNom: corr.catNom ?? item.catNom,
                        catCouleur: corr.catCouleur ?? item.catCouleur,
                        rayonNom: corr.rayonNom ?? item.rayonNom,
                        rayonCouleur: corr.rayonCouleur ?? item.rayonCouleur,
                        rayonOrdre: corr.rayonOrdre ?? item.rayonOrdre,
                        modifiePar: item.modifiePar,
                      );
                    }
                  }
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
                      final nomCat = data['catNom'] as String?;
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
                  await _localDb.insertArticleListe(await _garantirNom(item));
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

    // Catalogues partagés que je SUIS (membre non-propriétaire) : fusion en
    // temps réel dans mon catalogue local.
    _subs['catalogues_partages'] = _cataloguesPartagesCol
        .where('membres', arrayContains: _uid)
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        final catId = change.doc.id;
        final data = change.doc.data() as Map<String, dynamic>?;
        // Le mien (j'en suis la source) : rien à fusionner.
        if (data?['proprietaireId'] == _uid) continue;
        if (change.type == DocumentChangeType.removed) {
          for (final sub in ['categories', 'rayons', 'articles']) {
            await _subs.remove('cat_suivi_${catId}_$sub')?.cancel();
          }
          await _localDb.supprimerCatalogueSuivi(catId);
          continue;
        }
        // Un écouteur par sous-collection : tout changement re-fusionne.
        for (final sub in ['categories', 'rayons', 'articles']) {
          _subs.putIfAbsent('cat_suivi_${catId}_$sub', () {
            return _cataloguesPartagesCol
                .doc(catId)
                .collection(sub)
                .snapshots()
                .listen((_) async {
              await _stockerCatalogueSuivi(catId);
              onChangement();
            });
          });
        }
        await _stockerCatalogueSuivi(catId);
        onChangement();
      }
    });
  }

  // Récupère les 3 sous-collections d'un catalogue suivi et les stocke À PART
  // (catalogue séparé, marqué `source` = catId), remplaçant la version locale
  // précédente. N'affecte pas mon propre catalogue.
  Future<void> _stockerCatalogueSuivi(String catId) async {
    final doc = _cataloguesPartagesCol.doc(catId);
    final infos = await doc.get();
    final nom = infos.exists
        ? ((infos.data() as Map)['nom'] as String? ?? 'Catalogue partagé')
        : 'Catalogue partagé';
    final cats = (await doc.collection('categories').get())
        .docs
        .map((d) => Categorie.fromMap(d.data()))
        .toList();
    final rayons = (await doc.collection('rayons').get())
        .docs
        .map((d) => Rayon.fromMap(d.data()))
        .toList();
    final articles = (await doc.collection('articles').get())
        .docs
        .map((d) => Article.fromMap(d.data()))
        .toList();
    await _localDb.remplacerCatalogueSuivi(
      catId,
      articles: articles,
      categories: cats,
      rayons: rayons,
      nom: nom,
    );
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

  // ── CATALOGUE PARTAGÉ EN TEMPS RÉEL (sens unique) ───────────────
  // Le propriétaire partage son catalogue ; les membres le reçoivent et le
  // fusionnent en direct (par nom). Un seul catalogue partagé par compte
  // (doc d'id = uid du propriétaire).

  // Partage mon catalogue et retourne le code à transmettre (idempotent).
  Future<String> partagerMonCatalogue() async {
    final uid = _uid;
    final docRef = _cataloguesPartagesCol.doc(uid);
    final snap = await docRef.get();
    String code;
    if (snap.exists && (snap.data() as Map)['code'] != null) {
      code = (snap.data() as Map)['code'] as String;
    } else {
      do {
        code = _genererCode();
      } while ((await _codesCatalogueCol.doc(code).get()).exists);
      await docRef.set({
        'proprietaireId': uid,
        'membres': [uid],
        'code': code,
        'nom': _auth.currentUser?.displayName ?? 'Catalogue partagé',
      });
      await _codesCatalogueCol.doc(code).set({'catalogueId': uid});
    }
    await republierMonCatalogue();
    return code;
  }

  // (Re)pousse l'intégralité de mon catalogue vers le doc partagé. Appelé au
  // partage, et à rappeler pour propager mes changements aux membres.
  Future<void> republierMonCatalogue() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final docRef = _cataloguesPartagesCol.doc(uid);
    if (!(await docRef.get()).exists) return; // pas de catalogue partagé
    final cats = await _localDb.getCategories();
    final rayons = await _localDb.getRayons();
    final articles = await _localDb.getArticles();
    // Écrit par paquets (limite de 500 opérations par batch Firestore).
    final ops = <(DocumentReference, Map<String, dynamic>)>[
      for (final c in cats) (docRef.collection('categories').doc(c.id), c.toMap()),
      for (final r in rayons) (docRef.collection('rayons').doc(r.id), r.toMap()),
      for (final a in articles) (docRef.collection('articles').doc(a.id), a.toMap()),
    ];
    for (var i = 0; i < ops.length; i += 400) {
      final batch = _db.batch();
      for (final (ref, map) in ops.skip(i).take(400)) {
        batch.set(ref, map);
      }
      await batch.commit();
    }
  }

  // Suit le catalogue d'un autre compte via son code. Fusionne immédiatement,
  // puis l'écoute temps réel prend le relais. Retourne false si code invalide.
  Future<bool> suivreCatalogue(String code) async {
    final codeDoc =
        await _codesCatalogueCol.doc(code.trim().toUpperCase()).get();
    if (!codeDoc.exists) return false;
    final catId = (codeDoc.data() as Map<String, dynamic>)['catalogueId'] as String;
    if (catId == _uid) return false; // ne pas se suivre soi-même
    await _cataloguesPartagesCol.doc(catId).update({
      'membres': FieldValue.arrayUnion([_uid]),
    });
    await _stockerCatalogueSuivi(catId);
    return true;
  }

  // Arrête de suivre un catalogue (se retire des membres).
  Future<void> arreterDeSuivreCatalogue(String catId) async {
    await _cataloguesPartagesCol.doc(catId).update({
      'membres': FieldValue.arrayRemove([_uid]),
    });
    await _localDb.supprimerCatalogueSuivi(catId);
  }

  // Mon code de partage de catalogue (null si je ne partage pas).
  Future<String?> monCodeCatalogue() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _cataloguesPartagesCol.doc(uid).get();
    return snap.exists ? (snap.data() as Map)['code'] as String? : null;
  }

  // Les ids des catalogues que je SUIS (membre, non propriétaire).
  Future<List<String>> cataloguesSuivis() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _cataloguesPartagesCol
        .where('membres', arrayContains: uid)
        .get();
    return snap.docs
        .where((d) => (d.data() as Map)['proprietaireId'] != uid)
        .map((d) => d.id)
        .toList();
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

  // Le PROPRIÉTAIRE d'une liste impose ses catégories : si l'article (rapproché
  // par nom) existe à SON catalogue, on écrase la catégorie transportée par la
  // sienne dans le document partagé, pour que tous les membres voient la même.
  // Si le propriétaire n'a pas l'article, on ne touche à rien → la catégorie de
  // la personne qui l'a ajouté est conservée.
  // Retourne la catégorie du propriétaire à appliquer (et met à jour Firestore
  // si besoin), ou null si le propriétaire n'a pas cet article. Le retour sert
  // aussi à corriger la copie LOCALE du propriétaire : sa propre écriture
  // Firestore est ignorée par son listener (hasPendingWrites), il ne la
  // reverrait donc jamais autrement.
  Future<
      ({
        String? catNom,
        int? catCouleur,
        String? rayonNom,
        int? rayonCouleur,
        int? rayonOrdre
      })?> _imposerCategorieProprietaire(
      String listeId, String docId, Map<String, dynamic> data) async {
    final nomArticle = data['nomArticle'] as String?;
    if (nomArticle == null || nomArticle.isEmpty) return null;
    final catalogue = await _localDb.getArticles();
    final art = catalogue
        .where((a) => _normNom(a.nom) == _normNom(nomArticle))
        .firstOrNull;
    if (art == null) return null; // le propriétaire n'a pas cet article

    // Catégorie du propriétaire (si assignée).
    String? cNom;
    int? cCoul;
    if (art.categorieId != null) {
      final cats = await _localDb.getCategories();
      final c = cats.where((x) => x.id == art.categorieId).firstOrNull;
      cNom = c?.nom;
      cCoul = c?.couleur;
    }
    // Rayon magasin du propriétaire (si assigné).
    String? rNom;
    int? rCoul;
    int? rOrdre;
    if (art.rayonId != null) {
      final rayons = await _localDb.getRayons();
      final r = rayons.where((x) => x.id == art.rayonId).firstOrNull;
      rNom = r?.nom;
      rCoul = r?.couleur;
      rOrdre = r?.ordre;
    }
    if (cNom == null && rNom == null) return null; // rien à imposer

    // Ne met à jour Firestore que ce qui change réellement.
    final maj = <String, dynamic>{};
    if (cNom != null &&
        (data['catNom'] != cNom ||
            (data['catCouleur'] as num?)?.toInt() != cCoul)) {
      maj['catNom'] = cNom;
      maj['catCouleur'] = cCoul;
    }
    if (rNom != null &&
        (data['rayonNom'] != rNom ||
            (data['rayonCouleur'] as num?)?.toInt() != rCoul ||
            (data['rayonOrdre'] as num?)?.toInt() != rOrdre)) {
      maj['rayonNom'] = rNom;
      maj['rayonCouleur'] = rCoul;
      maj['rayonOrdre'] = rOrdre;
    }
    if (maj.isNotEmpty) {
      maj['lastModifiedBy'] = _uid;
      await _listesPartageesCol
          .doc(listeId)
          .collection('articles')
          .doc(docId)
          .update(maj);
    }
    return (
      catNom: cNom,
      catCouleur: cCoul,
      rayonNom: rNom,
      rayonCouleur: rCoul,
      rayonOrdre: rOrdre
    );
  }

  // Garantit qu'une ligne de liste collaborative porte un nom affichable avant
  // insertion locale : le nom reçu, sinon celui déjà stocké localement (ne pas
  // l'écraser par null), sinon celui de l'article s'il est à mon catalogue.
  // Sans ça, une ligne dont le doc Firestore n'a pas (encore) `nomArticle`
  // restait sans nom et disparaissait de la liste (compteur inférieur au widget).
  Future<ArticleListe> _garantirNom(ArticleListe item) async {
    if (item.nomArticle != null && item.nomArticle!.isNotEmpty) return item;
    // 1) Nom déjà présent sur la ligne locale (sync précédente).
    final locales = await _localDb.getArticlesListe(item.listeId);
    final ancien = locales.where((e) => e.id == item.id).firstOrNull;
    if (ancien?.nomArticle != null && ancien!.nomArticle!.isNotEmpty) {
      return item.copyWith(nomArticle: ancien.nomArticle);
    }
    // 2) Nom depuis mon catalogue si j'ai l'article.
    final art = (await _localDb.getArticles())
        .where((a) => a.id == item.articleId)
        .firstOrNull;
    if (art != null) return item.copyWith(nomArticle: art.nom);
    return item;
  }

  static String _normNom(String s) {
    const a = 'àâäéèêëïîôöùûüçñ';
    const b = 'aaaeeeeiioouuucn';
    var out = s.trim().toLowerCase();
    for (var i = 0; i < a.length; i++) {
      out = out.replaceAll(a[i], b[i]);
    }
    return out;
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

  // Filet de sécurité : ré-importe TOUS les articles des listes collaboratives
  // depuis Firestore (au cas où l'écoute temps réel aurait raté des documents,
  // ce qui donnait un compteur incomplet, ex. « 0/15 » au lieu de « 0/39 »).
  // Insertion seule (jamais de suppression) : ne peut pas perdre d'article.
  Future<void> reconcilierPullListesPartagees() async {
    if (!_estConnecte) return;
    final snap = await _listesPartageesCol
        .where('membres', arrayContains: _uid)
        .get();
    for (final doc in snap.docs) {
      final listeId = doc.id;
      final itemsSnap =
          await _listesPartageesCol.doc(listeId).collection('articles').get();
      final catalogueIds =
          (await _localDb.getArticles()).map((a) => a.id).toSet();
      for (final itemDoc in itemsSnap.docs) {
        try {
          final data = itemDoc.data();
          final item = ArticleListe.fromMap(data);
          // Recrée l'article local minimal s'il manque, pour que la ligne
          // s'affiche ET soit comptée par le widget.
          final nomArticle = data['nomArticle'] as String?;
          if (nomArticle != null &&
              nomArticle.isNotEmpty &&
              !catalogueIds.contains(item.articleId)) {
            await _localDb
                .insertArticle(Article(id: item.articleId, nom: nomArticle));
            catalogueIds.add(item.articleId);
          }
          await _localDb.insertArticleListe(await _garantirNom(item));
        } catch (_) {
          continue;
        }
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
      // Priorité à l'instantané DÉJÀ porté par la ligne (typiquement la
      // catégorie que le propriétaire a imposée et qu'on a reçue) : sans ça, la
      // réconciliation au retour de l'app ré-écraserait la catégorie du
      // propriétaire par la mienne. Ce n'est qu'à défaut (nouvel ajout, catNom
      // encore nul) qu'on prend la catégorie locale de l'article.
      String? nomCat = al.catNom;
      int? couleurCat = al.catCouleur;
      if (nomCat == null && article?.categorieId != null) {
        final cats = await _localDb.getCategories();
        final cat =
            cats.where((c) => c.id == article!.categorieId).firstOrNull;
        nomCat = cat?.nom;
        couleurCat = cat?.couleur;
      }
      // Même logique pour le rayon magasin (nom + couleur + ordre).
      String? nomRayon = al.rayonNom;
      int? couleurRayon = al.rayonCouleur;
      int? ordreRayon = al.rayonOrdre;
      if (nomRayon == null && article?.rayonId != null) {
        final rayons = await _localDb.getRayons();
        final r = rayons.where((x) => x.id == article!.rayonId).firstOrNull;
        nomRayon = r?.nom;
        couleurRayon = r?.couleur;
        ordreRayon = r?.ordre;
      }
      await _listesPartageesCol
          .doc(al.listeId)
          .collection('articles')
          .doc(al.id)
          .set({
        ...al.toMap(),
        // Instantané de catégorie ET de rayon transporté avec l'article, pour
        // un regroupement identique chez tous les membres (l'al local du
        // vendeur a ces champs nuls, on les écrase ici avec ses vraies valeurs).
        'catNom': nomCat,
        'catCouleur': couleurCat,
        'rayonNom': nomRayon,
        'rayonCouleur': couleurRayon,
        'rayonOrdre': ordreRayon,
        'lastModifiedBy': _uid,
        // Nom dénormalisé : celui de mon article si je l'ai, sinon celui déjà
        // porté par la ligne (ajouté par un autre membre). Ne JAMAIS l'écraser
        // par null quand je n'ai pas l'article à mon catalogue, sinon les autres
        // membres perdent le nom et la ligne disparaît de leur liste.
        if ((article?.nom ?? al.nomArticle) != null)
          'nomArticle': article?.nom ?? al.nomArticle,
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
