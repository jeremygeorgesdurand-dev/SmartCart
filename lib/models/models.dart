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

  ArticleListe({
    required this.id,
    required this.listeId,
    required this.articleId,
    this.quantite = 1,
    this.unite,
    this.note,
    this.coche = false,
  });

  ArticleListe copyWith({
    int? quantite,
    String? unite,
    String? note,
    bool? coche,
  }) =>
      ArticleListe(
        id: id,
        listeId: listeId,
        articleId: articleId,
        quantite: quantite ?? this.quantite,
        unite: unite ?? this.unite,
        note: note ?? this.note,
        coche: coche ?? this.coche,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'listeId': listeId,
        'articleId': articleId,
        'quantite': quantite,
        'unite': unite,
        'note': note,
        'coche': coche ? 1 : 0,
      };

  factory ArticleListe.fromMap(Map<String, dynamic> map) => ArticleListe(
        id: map['id'],
        listeId: map['listeId'],
        articleId: map['articleId'],
        quantite: map['quantite'] ?? 1,
        unite: map['unite'],
        note: map['note'],
        coche: map['coche'] == 1,
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

  ListeCourses({
    required this.id,
    required this.nom,
    DateTime? createdAt,
    this.magasin,
    this.archivee = false,
  }) : createdAt = createdAt ?? DateTime.now();

  ListeCourses copyWith({
    String? nom,
    String? magasin,
    bool? archivee,
  }) =>
      ListeCourses(
        id: id,
        nom: nom ?? this.nom,
        createdAt: createdAt,
        magasin: magasin ?? this.magasin,
        archivee: archivee ?? this.archivee,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'createdAt': createdAt.toIso8601String(),
        'magasin': magasin,
        'archivee': archivee ? 1 : 0,
      };

  factory ListeCourses.fromMap(Map<String, dynamic> map) => ListeCourses(
        id: map['id'],
        nom: map['nom'],
        createdAt: DateTime.parse(map['createdAt']),
        magasin: map['magasin'],
        archivee: map['archivee'] == 1,
      );
}
