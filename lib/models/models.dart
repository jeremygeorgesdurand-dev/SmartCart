import 'dart:convert';

// ============================================================
// models/article.dart
// ============================================================
class Article {
  final String id;
  final String nom;
  final String? categorieId;
  final String? rayonId;
  final String? barcode;
  final String? marque;
  final String? imageUrl;
  final DateTime createdAt;

  Article({
    required this.id,
    required this.nom,
    this.categorieId,
    this.rayonId,
    this.barcode,
    this.marque,
    this.imageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Article copyWith({
    String? nom,
    String? categorieId,
    String? rayonId,
    String? barcode,
    String? marque,
    String? imageUrl,
  }) =>
      Article(
        id: id,
        nom: nom ?? this.nom,
        categorieId: categorieId ?? this.categorieId,
        rayonId: rayonId ?? this.rayonId,
        barcode: barcode ?? this.barcode,
        marque: marque ?? this.marque,
        imageUrl: imageUrl ?? this.imageUrl,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'categorieId': categorieId,
        'rayonId': rayonId,
        'barcode': barcode,
        'marque': marque,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Article.fromMap(Map<String, dynamic> map) => Article(
        id: map['id'],
        nom: map['nom'],
        categorieId: map['categorieId'],
        rayonId: map['rayonId'],
        barcode: map['barcode'],
        marque: map['marque'],
        imageUrl: map['imageUrl'],
        createdAt: DateTime.parse(map['createdAt']),
      );

  // Égalité par id : le catalogue est ré-instancié à chaque lecture de la
  // base (nouveaux objets Article à chaque fois). Sans ceci, un provider
  // family keyé par Article (ex: prixIndicatifProvider) traite chaque
  // nouvelle instance comme une clé différente et relance inutilement sa
  // requête réseau au moindre rebuild, au lieu de réutiliser le résultat
  // déjà en cache pour le même article.
  @override
  bool operator ==(Object other) => other is Article && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ============================================================
// models/categorie.dart
// ============================================================
class Categorie {
  final String id;
  final String nom;
  final int couleur; // stocké comme int (Color.value)
  final int ordre;   // pour le tri personnalisé

  Categorie({
    required this.id,
    required this.nom,
    required this.couleur,
    required this.ordre,
  });

  Categorie copyWith({String? nom, int? couleur, int? ordre}) => Categorie(
        id: id,
        nom: nom ?? this.nom,
        couleur: couleur ?? this.couleur,
        ordre: ordre ?? this.ordre,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'couleur': couleur,
        'ordre': ordre,
      };

  factory Categorie.fromMap(Map<String, dynamic> map) => Categorie(
        id: map['id'],
        nom: map['nom'],
        couleur: map['couleur'],
        ordre: map['ordre'],
      );
}

// ============================================================
// models/rayon.dart
// ============================================================
class Rayon {
  final String id;
  final String nom;
  final int ordre;
  final String? magasin;
  final int couleur; // couleur comme les catégories

  Rayon({
    required this.id,
    required this.nom,
    required this.ordre,
    this.magasin,
    this.couleur = 0xFF607D8B, // gris bleuté par défaut
  });

  Rayon copyWith({String? nom, int? ordre, String? magasin, int? couleur}) => Rayon(
        id: id,
        nom: nom ?? this.nom,
        ordre: ordre ?? this.ordre,
        magasin: magasin ?? this.magasin,
        couleur: couleur ?? this.couleur,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'ordre': ordre,
        'magasin': magasin,
        'couleur': couleur,
      };

  factory Rayon.fromMap(Map<String, dynamic> map) => Rayon(
        id: map['id'],
        nom: map['nom'],
        ordre: map['ordre'],
        magasin: map['magasin'],
        couleur: map['couleur'] ?? 0xFF607D8B,
      );
}

// ============================================================
// models/article_liste.dart  (article dans une liste de courses)
// ============================================================
class ArticleListe {
  final String id;
  final String listeId;
  final String articleId;
  final int quantite;
  final String? unite;    // ex: kg, L, unité
  final String? note;
  final bool coche;       // coché en magasin
  // Instantané de la catégorie de l'article AU MOMENT de l'ajout, transporté
  // avec l'article dans une liste collaborative. Les catégories étant propres
  // à chaque compte, c'est ce qui permet à tous les membres de voir le même
  // regroupement (« Organisation par liste ») sans partager leur catalogue.
  // Nul pour les listes personnelles (on y utilise la catégorie live locale).
  final String? catNom;
  final int? catCouleur;
  // uid du dernier membre ayant ajouté/modifié/coché cette ligne (liste
  // collaborative). Sert à afficher « qui a fait quoi ». Nul en local perso.
  final String? modifiePar;

  ArticleListe({
    required this.id,
    required this.listeId,
    required this.articleId,
    this.quantite = 1,
    this.unite,
    this.note,
    this.coche = false,
    this.catNom,
    this.catCouleur,
    this.modifiePar,
  });

  ArticleListe copyWith({
    int? quantite,
    String? unite,
    String? note,
    bool? coche,
    String? modifiePar,
  }) =>
      ArticleListe(
        id: id,
        listeId: listeId,
        articleId: articleId,
        quantite: quantite ?? this.quantite,
        unite: unite ?? this.unite,
        note: note ?? this.note,
        coche: coche ?? this.coche,
        catNom: catNom,
        catCouleur: catCouleur,
        modifiePar: modifiePar ?? this.modifiePar,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'listeId': listeId,
        'articleId': articleId,
        'quantite': quantite,
        'unite': unite,
        'note': note,
        'coche': coche ? 1 : 0,
        'catNom': catNom,
        'catCouleur': catCouleur,
        'modifiePar': modifiePar,
      };

  factory ArticleListe.fromMap(Map<String, dynamic> map) => ArticleListe(
        id: map['id'],
        listeId: map['listeId'],
        articleId: map['articleId'],
        quantite: map['quantite'] ?? 1,
        unite: map['unite'],
        note: map['note'],
        coche: map['coche'] == 1,
        catNom: map['catNom'] as String?,
        catCouleur: (map['catCouleur'] as num?)?.toInt(),
        // Local : 'modifiePar'. Depuis Firestore (liste partagée) : la Cloud
        // Function/écriture pose 'lastModifiedBy'.
        modifiePar:
            (map['modifiePar'] ?? map['lastModifiedBy']) as String?,
      );
}

// ============================================================
// models/liste_courses.dart
// ============================================================
class ListeCourses {
  final String id;
  final String nom;
  final DateTime createdAt;
  final String? magasin;
  final bool archivee;
  final bool partagee; // liste collaborative (plusieurs comptes)
  final String? code; // code à 6 caractères pour rejoindre la liste
  final int couleur;

  ListeCourses({
    required this.id,
    required this.nom,
    DateTime? createdAt,
    this.magasin,
    this.archivee = false,
    this.partagee = false,
    this.code,
    this.couleur = 0xFF1ABC9C,
  }) : createdAt = createdAt ?? DateTime.now();

  ListeCourses copyWith({
    String? nom,
    String? magasin,
    bool? archivee,
    bool? partagee,
    String? code,
    int? couleur,
  }) =>
      ListeCourses(
        id: id,
        nom: nom ?? this.nom,
        createdAt: createdAt,
        magasin: magasin ?? this.magasin,
        archivee: archivee ?? this.archivee,
        partagee: partagee ?? this.partagee,
        code: code ?? this.code,
        couleur: couleur ?? this.couleur,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'createdAt': createdAt.toIso8601String(),
        'magasin': magasin,
        'archivee': archivee ? 1 : 0,
        'partagee': partagee ? 1 : 0,
        'code': code,
        'couleur': couleur,
      };

  factory ListeCourses.fromMap(Map<String, dynamic> map) => ListeCourses(
        id: map['id'],
        nom: map['nom'],
        createdAt: DateTime.parse(map['createdAt']),
        magasin: map['magasin'],
        archivee: map['archivee'] == 1,
        partagee: map['partagee'] == 1,
        code: map['code'],
        couleur: map['couleur'] as int? ?? 0xFF1ABC9C,
      );
}

// ============================================================
// models/prix_article.dart  (prix estimé d'un article du catalogue)
// ============================================================
class PrixArticle {
  final String articleId;
  final double prix;
  // '' = pas de magasin précisé (prix générique). Permet de comparer
  // plusieurs prix pour un même article selon le magasin.
  final String magasin;

  PrixArticle({required this.articleId, required this.prix, this.magasin = ''});

  Map<String, dynamic> toMap() => {
        'articleId': articleId,
        'prix': prix,
        'magasin': magasin,
      };

  factory PrixArticle.fromMap(Map<String, dynamic> map) => PrixArticle(
        articleId: map['articleId'],
        prix: (map['prix'] as num).toDouble(),
        magasin: map['magasin'] as String? ?? '',
      );
}

// Historique des prix saisis dans le temps (local uniquement, pas
// synchronisé au cloud) : sert à tracer l'évolution d'un article/magasin.
class PrixHistorique {
  final String id;
  final String articleId;
  final String magasin;
  final double prix;
  final DateTime date;

  PrixHistorique({
    required this.id,
    required this.articleId,
    required this.prix,
    this.magasin = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'articleId': articleId,
        'magasin': magasin,
        'prix': prix,
        'date': date.toIso8601String(),
      };

  factory PrixHistorique.fromMap(Map<String, dynamic> map) => PrixHistorique(
        id: map['id'],
        articleId: map['articleId'],
        magasin: map['magasin'] as String? ?? '',
        prix: (map['prix'] as num).toDouble(),
        date: DateTime.parse(map['date']),
      );
}

// ============================================================
// RECETTES — local uniquement (pas synchronisé au cloud)
// ============================================================
class IngredientRecette {
  final String nom;
  final int quantite;
  final String? unite;

  IngredientRecette({required this.nom, this.quantite = 1, this.unite});

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'quantite': quantite,
        'unite': unite,
      };

  factory IngredientRecette.fromMap(Map<String, dynamic> map) =>
      IngredientRecette(
        nom: map['nom'] as String,
        quantite: map['quantite'] as int? ?? 1,
        unite: map['unite'] as String?,
      );
}

class Recette {
  final String id;
  final String nom;
  final int portions;
  final List<IngredientRecette> ingredients;
  // Étapes de préparation et image (renseignées par l'import depuis une URL ;
  // vides pour une recette créée à la main sans les saisir).
  final List<String> etapes;
  final String? imageUrl;

  Recette({
    required this.id,
    required this.nom,
    this.portions = 4,
    this.ingredients = const [],
    this.etapes = const [],
    this.imageUrl,
  });

  Recette copyWith({
    String? nom,
    int? portions,
    List<IngredientRecette>? ingredients,
    List<String>? etapes,
    String? imageUrl,
  }) =>
      Recette(
        id: id,
        nom: nom ?? this.nom,
        portions: portions ?? this.portions,
        ingredients: ingredients ?? this.ingredients,
        etapes: etapes ?? this.etapes,
        imageUrl: imageUrl ?? this.imageUrl,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'portions': portions,
        'ingredientsJson':
            jsonEncode(ingredients.map((i) => i.toMap()).toList()),
        'etapesJson': jsonEncode(etapes),
        'imageUrl': imageUrl,
      };

  factory Recette.fromMap(Map<String, dynamic> map) {
    final ingredientsRaw = map['ingredientsJson'] as String? ?? '[]';
    final ingredients = (jsonDecode(ingredientsRaw) as List)
        .map((e) => IngredientRecette.fromMap(e as Map<String, dynamic>))
        .toList();
    final etapesRaw = map['etapesJson'] as String? ?? '[]';
    final etapes = (jsonDecode(etapesRaw) as List)
        .map((e) => e.toString())
        .toList();
    return Recette(
      id: map['id'] as String,
      nom: map['nom'] as String,
      portions: map['portions'] as int? ?? 4,
      ingredients: ingredients,
      etapes: etapes,
      imageUrl: map['imageUrl'] as String?,
    );
  }
}
