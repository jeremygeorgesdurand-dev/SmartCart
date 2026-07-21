class VersionInfo {
  static const String version = '1.0.0';
  static const String buildNumber = '25';
  static const String dateMiseAJour = '18 avril 2026';

  static const List<Release> historique = [
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
