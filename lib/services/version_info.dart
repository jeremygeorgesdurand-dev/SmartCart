class VersionInfo {
  // À INCRÉMENTER À CHAQUE CHANGEMENT : patch (1.2.0 → 1.2.1) pour un
  // correctif, mineur (1.2.0 → 1.3.0) pour une nouvelle fonctionnalité. Garder
  // `version` et `buildNumber` alignés avec le champ `version:` du pubspec
  // (buildNumber = numéro après le +), et ajouter une entrée dans historique.
  static const String version = '1.3.0';
  static const String buildNumber = '28';
  static const String dateMiseAJour = '15 août 2026';

  static const List<Release> historique = [
    Release(
      version: '1.3.0',
      date: '15 août 2026',
      changements: [
        'Listes collaboratives : chaque article emporte sa catégorie '
            '(nom + couleur), donc tout le monde voit le même regroupement '
            'et le même ordre, même sans avoir les mêmes catégories',
      ],
    ),
    Release(
      version: '1.2.0',
      date: '15 août 2026',
      changements: [
        'Nouvel onglet Recettes : dataset français local (Wikilivres), '
            'recherche, filtres, suggestions « d\'après mon frigo »',
        'Import d\'une recette depuis une URL (ingrédients, étapes, photo)',
        'Reconnaissance d\'un fruit/légume par photo (IA locale, hors-ligne)',
        'Prix depuis une photo du ticket de caisse (lecture locale, hors-ligne)',
        'Import de recette : entités HTML et balises enfin décodées',
        'Catalogue trié en ignorant les accents (« Pâte » avec les P)',
        'Doublons : moins de faux positifs, catégories affichées, '
            'suppression en un geste',
        'Widget : compteur d\'en-tête cohérent avec la liste',
        'Prix indicatifs qui apparaissent d\'eux-mêmes plus souvent',
        'Listes collaboratives : articles des autres visibles, '
            'suppression possible par le propriétaire',
        'Catégories affichées sur chaque article des listes',
        'Numéro de version affiché et incrémenté à chaque mise à jour',
      ],
    ),
    Release(
      version: '1.1.0',
      date: '28 juillet 2026',
      changements: [
        'Paramètres réorganisés en sous-menus (Apparence, Organisation, '
            'Fonctionnalités, Données, À propos)',
        'Widget écran d\'accueil adaptatif à la taille choisie',
        'Unité manuelle (kg/g/L/mL) sur les articles d\'une liste',
        'Liste générée automatiquement d\'après les habitudes d\'achat',
        'Récapitulatif de fin de courses en page dédiée',
        'Rejoindre une liste collaborative par QR code',
        'Budget et historique des dépenses basés sur les achats réels',
        'Listes archivées enfin consultables',
        'Navigation par glissement entre les onglets',
      ],
    ),
    Release(
      version: '1.0.0',
      date: '18 avril 2026',
      changements: [
        'Connexion Google + sauvegarde Firebase temps réel',
        'Import/Export de listes avec catégories complètes',
        'Mode courses : cochés descendent en bas',
        'Reconnaissance vocale robuste sans duplication',
        'Scanner code-barres + Open Food Facts',
        '16 thèmes de couleur persistants',
        'Couleurs par rayon magasin',
        'Stats détaillées avec top articles',
        'Logo en arrière-plan personnalisable',
        'Historique des versions',
      ],
    ),
    Release(
      version: '0.9.0',
      date: '10 avril 2026',
      changements: [
        'Rayons magasin avec couleurs',
        'Paramètres persistants après redémarrage',
        'Tri des listes alphabétique/date',
        'Appui long sur article pour options',
        'Import catalogue avec mise à jour catégories',
      ],
    ),
    Release(
      version: '0.8.0',
      date: '1 avril 2026',
      changements: [
        'Première version publique',
        'Catalogue, listes, catégories maison',
        'Reconnaissance vocale',
        'Scanner code-barres basique',
      ],
    ),
  ];
}

class Release {
  final String version;
  final String date;
  final List<String> changements;
  const Release({
    required this.version,
    required this.date,
    required this.changements,
  });
}
