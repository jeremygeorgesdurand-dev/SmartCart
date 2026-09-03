class VersionInfo {
  // À INCRÉMENTER À CHAQUE CHANGEMENT : patch (1.2.0 → 1.2.1) pour un
  // correctif, mineur (1.2.0 → 1.3.0) pour une nouvelle fonctionnalité. Garder
  // `version` et `buildNumber` alignés avec le champ `version:` du pubspec
  // (buildNumber = numéro après le +), et ajouter une entrée dans historique.
  static const String version = '1.25.2';
  static const String buildNumber = '54';
  static const String dateMiseAJour = '3 septembre 2026';

  static const List<Release> historique = [
    Release(
      version: '1.25.2',
      date: '3 septembre 2026',
      changements: [
        'Partage d\'un profil avec une liste : quand une liste personnelle '
            'devient collaborative, la personne qui rejoint voit enfin les '
            'articles qui étaient déjà dedans (leur nom est bien transmis)',
      ],
    ),
    Release(
      version: '1.25.1',
      date: '2 septembre 2026',
      changements: [
        'Catalogue : le choix de la quantité fonctionne de façon fiable — '
            'toucher les boutons − / + ne dé-sélectionne plus l\'article par '
            'erreur (la quantité choisie est bien enregistrée dans la liste)',
        'Correction d\'un plantage possible du sélecteur de liste dans le '
            'Catalogue après un rechargement des listes',
      ],
    ),
    Release(
      version: '1.25.0',
      date: '27 août 2026',
      changements: [
        'Nouveau : Profils magasin (Réglages → Organisation). Chaque profil a '
            'sa propre organisation de rayons (ordre + couleurs) ET l\'aisle de '
            'chaque article, plus une liste associée — un profil par magasin',
        'On bascule d\'un profil à l\'autre en un geste : toute l\'organisation '
            'suit (rayons, ordre de courses, affectation des articles)',
        'Partage d\'un profil par QR code ou code : l\'organisation ET la liste '
            'associée sont partagées d\'un coup',
      ],
    ),
    Release(
      version: '1.24.0',
      date: '27 août 2026',
      changements: [
        'Catalogue : après avoir ajouté des articles à une liste, la liste '
            'reste sélectionnée — on peut enchaîner les ajouts sans la '
            're-choisir',
        'Catalogue : en cochant un article à ajouter, on choisit sa quantité '
            '(− n +) directement',
        'Petits messages en bas de l\'écran plus courts et qui ne s\'empilent '
            'plus (ils partent au bout de quelques secondes)',
      ],
    ),
    Release(
      version: '1.23.0',
      date: '25 août 2026',
      changements: [
        'Listes collaboratives : correction majeure de synchro. L\'appareil qui '
            'se connecte ne réécrase plus la liste avec son ancien état : les '
            'articles cochés/supprimés par l\'autre personne sont respectés '
            '(fini les articles qui se dé-cochaient ou réapparaissaient, et la '
            'liste vidée qui se re-remplissait)',
        'Un ajout fait depuis le widget à une liste collaborative est poussé de '
            'façon ciblée, sans écraser le reste de la liste',
      ],
    ),
    Release(
      version: '1.22.0',
      date: '25 août 2026',
      changements: [
        'Catalogue : le bouton « Mon catalogue » du sélecteur fonctionne enfin '
            '(on peut revenir à son catalogue après avoir ouvert un catalogue '
            'suivi)',
        'Listes collaboratives : les articles gardent leur nom même quand ils '
            'ne sont pas à ton catalogue — plus de lignes qui manquaient (le '
            'compteur rejoint celui du widget). Le nom est récupéré et conservé '
            'au fil des synchronisations',
      ],
    ),
    Release(
      version: '1.21.0',
      date: '25 août 2026',
      changements: [
        'Listes collaboratives fiabilisées : le nombre d\'articles est enfin '
            'cohérent partout (liste, widget, mode courses). Les articles reçus '
            's\'affichent toujours, même s\'ils ne sont pas dans ton catalogue',
        'Une liste collaborative ne se vide plus toute seule, et dupliquer une '
            'liste crée bien une copie indépendante (elles ne sont plus liées)',
        'Catalogue suivi : bascule SANS changer d\'écran — « Mon catalogue ▾ » '
            'ne change que la liste des articles ; la recherche, les filtres et '
            'le sélecteur restent en place. On peut passer d\'un catalogue à '
            'l\'autre et revenir au sien instantanément',
      ],
    ),
    Release(
      version: '1.20.0',
      date: '25 août 2026',
      changements: [
        'Catalogue suivi : bascule dans le MÊME onglet (plus de nouvelle '
            'fenêtre) via « Mon catalogue ▾ » — on revient à son catalogue ou '
            'on change de catalogue suivi sans quitter l\'écran',
        'Liste collaborative : correction d\'une liste qui apparaissait vide '
            'dans l\'app alors que le widget comptait bien les articles (les '
            'articles recréés par la synchro sont désormais affichés)',
      ],
    ),
    Release(
      version: '1.19.0',
      date: '25 août 2026',
      changements: [
        'Catalogue suivi : même interface que ton catalogue (recherche + '
            'filtres par catégorie)',
        'Partage du catalogue par QR code, directement depuis le Catalogue '
            '(menu ⋮) : « Partager mon catalogue » affiche un QR, « Suivre un '
            'catalogue » scanne un QR ou saisit le code',
      ],
    ),
    Release(
      version: '1.18.0',
      date: '25 août 2026',
      changements: [
        'Réglages → Apparence : option « Rotation de l\'écran » (l\'app reste '
            'en portrait par défaut, la rotation devient un choix)',
        'Liste collaborative : filet de sécurité qui ré-importe tous les '
            'articles au retour dans l\'app, pour corriger un compteur '
            'incomplet (ex. 0/15 au lieu de 0/39)',
      ],
    ),
    Release(
      version: '1.17.0',
      date: '21 août 2026',
      changements: [
        'Catalogue suivi : coche des articles → « Ajouter à une liste » '
            '(existante ou nouvelle). Ils sont copiés dans ton catalogue et '
            'ajoutés à la liste, tout en gardant le catalogue suivi séparé',
      ],
    ),
    Release(
      version: '1.16.0',
      date: '21 août 2026',
      changements: [
        'Catalogue suivi = catalogue SÉPARÉ : un sélecteur « Mon catalogue ▾ » '
            'en haut du Catalogue permet de basculer sur un catalogue partagé '
            '(en lecture seule), sans mélanger avec le tien. On peut tout '
            'ajouter au sien ou arrêter de suivre',
      ],
    ),
    Release(
      version: '1.15.0',
      date: '21 août 2026',
      changements: [
        'Catalogue partagé en temps réel : partage ton catalogue via un code, '
            'les personnes qui suivent reçoivent tes articles/catégories en '
            'direct (fusionnés par nom). Réglages → Sauvegarde',
      ],
    ),
    Release(
      version: '1.14.0',
      date: '21 août 2026',
      changements: [
        'Importer une liste : choix « Créer une liste » ou « Ajouter au '
            'catalogue seulement » (sans créer de liste)',
      ],
    ),
    Release(
      version: '1.13.0',
      date: '21 août 2026',
      changements: [
        'Import de catalogue corrigé : il ne crée plus de liste, et les '
            'catégories/rayons sont fusionnés par NOM (plus de doublon) avec '
            'les articles rattachés à ta bonne catégorie locale',
      ],
    ),
    Release(
      version: '1.12.0',
      date: '21 août 2026',
      changements: [
        'Widget : nouveau bouton 🛒 qui ouvre directement le Mode courses de '
            'la liste',
      ],
    ),
    Release(
      version: '1.11.0',
      date: '21 août 2026',
      changements: [
        'Recettes simplifiées : « Mon frigo » n\'est plus un onglet séparé, '
            'on y accède par le bouton « Cuisiner avec mon frigo » depuis '
            'Explorer (2 sous-onglets au lieu de 3)',
      ],
    ),
    Release(
      version: '1.10.0',
      date: '21 août 2026',
      changements: [
        'Widget : le total estimé de la liste s\'affiche à côté du compteur',
        'Ticket : les articles au poids gardent leur prix au kilo (stable), '
            'plus le montant total qui dépend du poids',
        'Ticket : rapprochement des noms abrégés (« blanc de poule » → '
            '« Blanc de poulet ») pour éviter les doublons',
      ],
    ),
    Release(
      version: '1.9.0',
      date: '21 août 2026',
      changements: [
        'Ticket de caisse : message de confirmation, plus de doublons si on '
            'appuie plusieurs fois, noms nettoyés (poids/quantité retirés) et '
            'indication « déjà au catalogue » / « nouvel article »',
        'Budget : la liste des prix des articles est repliable',
        'Liste collaborative : le rayon magasin du propriétaire est aussi '
            'imposé (comme la catégorie), avec son ordre de courses',
      ],
    ),
    Release(
      version: '1.8.0',
      date: '21 août 2026',
      changements: [
        'Liste collaborative : un petit avatar montre qui a ajouté / coché '
            'chaque article',
      ],
    ),
    Release(
      version: '1.7.0',
      date: '19 août 2026',
      changements: [
        'Barre du bas simplifiée : les statistiques ne sont plus un onglet '
            'séparé, elles rejoignent l\'écran Budget (une section en bas)',
        'Moins de redondance : le budget n\'apparaît plus en double entre '
            'Budget et Stats',
      ],
    ),
    Release(
      version: '1.6.1',
      date: '19 août 2026',
      changements: [
        'Lecture de ticket : reconnaît enfin les tickets en colonnes '
            '(le nom et le prix étaient lus séparément) — « Aucun prix '
            'détecté » corrigé',
      ],
    ),
    Release(
      version: '1.6.0',
      date: '18 août 2026',
      changements: [
        'Lecture du ticket de caisse fiabilisée : reconnaît le format des '
            'hypermarchés (nom + prix unitaire), ignore remises et fidélité',
        'Application allégée : la reconnaissance d\'aliment par IA a été '
            'retirée (moins de place, plus de simplicité)',
        'Recettes : filtre « Avec photo » pour ne voir que les recettes '
            'illustrées',
      ],
    ),
    Release(
      version: '1.5.0',
      date: '18 août 2026',
      changements: [
        'Fin de courses : « Vider » la liste au lieu d\'archiver — garde les '
            'articles non trouvés pour la prochaine fois, et si tout est '
            'trouvé, vide la liste en la gardant créée (plus besoin d\'en '
            'recréer une)',
        'Récapitulatif de fin de courses embelli',
      ],
    ),
    Release(
      version: '1.4.0',
      date: '18 août 2026',
      changements: [
        'Partage du catalogue : envoie tes articles + catégories à une autre '
            'personne (Réglages → Sauvegarde), qui les fusionne dans son '
            'catalogue sans écraser le sien',
      ],
    ),
    Release(
      version: '1.3.1',
      date: '18 août 2026',
      changements: [
        'Liste collaborative : c\'est le propriétaire qui impose ses '
            'catégories. Un article ajouté par un membre prend la catégorie '
            'du propriétaire s\'il l\'a à son catalogue, sinon celle de la '
            'personne qui l\'a ajouté',
      ],
    ),
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
