import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/widget_service.dart';
import '../widgets/background_logo.dart';
import 'budget_screen.dart';
import 'catalogue_screen.dart';
import 'listes_screen.dart';
import 'parametres_screen.dart';
import 'recettes_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  // Nombre d'écrans de navigation (dépend des onglets activés) — tenu à jour
  // à chaque build, lu par les rappels de débordement de Recettes.
  int _nbEcrans = 6;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Le widget écran d'accueil ouvre l'app avec l'id de la liste tapée
    // (tap sur le nom/l'en-tête) via un extra d'intent : sans ce pont, on
    // atterrissait juste sur le dernier écran affiché, pas sur la liste
    // choisie.
    WidgetService.ecouterIntents(
        (action, listeId, __) => _ouvrirDepuisWidget(action, listeId));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final intent = await WidgetService.getWidgetIntent();
      final listeId = intent['liste_id'] ?? '';
      if (listeId.isNotEmpty) {
        _ouvrirDepuisWidget(intent['action'] ?? '', listeId);
      }
      // Au démarrage à froid, l'écoute temps réel a pu rater des articles de
      // liste collaborative (compteur incomplet / liste vide à l'ouverture) :
      // on réconcilie tout de suite, comme au retour au premier plan.
      unawaited(_syncSilencieuxResume());
      // En tâche de fond : va chercher un prix indicatif pour les articles
      // qui n'en ont pas encore, dès le démarrage, pour que le Budget soit
      // déjà rempli sans avoir à ouvrir chaque article un par un.
      unawaited(_rechaufferPrix());
    });
  }

  // Pré-charge les prix indicatifs en ligne, en arrière-plan et sans bloquer
  // l'UI. S'appuie sur le cache de prixIndicatifProvider (14 j si trouvé,
  // 45 min sinon) : les articles déjà connus reviennent instantanément ;
  // on ne temporise qu'après un vrai appel réseau, pour ne pas marteler les
  // API tout en restant économe. Les erreurs sont ignorées (best effort).
  Future<void> _rechaufferPrix() async {
    try {
      final articles = await ref.read(articlesNotifierProvider.future);
      final prix = await ref.read(prixArticlesNotifierProvider.future);
      final avecPrixConfirme = prix.map((p) => p.articleId).toSet();
      for (final a in articles) {
        if (!mounted) return;
        if (avecPrixConfirme.contains(a.id)) continue;
        final debut = DateTime.now();
        try {
          await ref.read(prixIndicatifProvider(a).future);
        } catch (_) {
          // réseau/API indisponible : on tentera au prochain démarrage
        }
        final aReseau = DateTime.now().difference(debut).inMilliseconds > 250;
        if (aReseau) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    } catch (_) {
      // catalogue/prix pas encore prêts : sans gravité
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Le "+" du widget écran d'accueil écrit un article/liste directement en
    // SQLite depuis du code natif (QuickAddActivity), sans jamais passer par
    // le moteur Flutter : les providers Riverpod (catalogue, articles d'une
    // liste) ne le savent pas et continuent de servir leurs données mises en
    // cache depuis avant la mise en arrière-plan. Sans invalidation ici, un
    // article ajouté par le widget peut être compté (une liste jamais visitée
    // depuis reconstruit son provider à jour) mais rester invisible dans le
    // détail de la liste (dont le provider catalogue était déjà construit,
    // donc périmé). Invalider au retour au premier plan force une relecture
    // fraîche de la base dans tous les cas.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(articlesNotifierProvider);
      ref.invalidate(listesNotifierProvider);
      ref.invalidate(articlesListeProvider);
      // Un article ajouté à une liste COLLABORATIVE depuis le widget n'est
      // écrit qu'en local (code natif) : on le ré-pousse vers Firestore au
      // retour au premier plan pour qu'il parvienne aux autres membres.
      unawaited(_syncSilencieuxResume());
    }
  }

  Future<void> _syncSilencieuxResume() async {
    try {
      final sync = ref.read(syncServiceProvider);
      // D'abord POUSSER mes items locaux, puis TIRER tout le cloud (filet de
      // sécurité contre un compteur incomplet sur une liste collaborative).
      await sync.reconcilierListesPartagees();
      await sync.reconcilierPullListesPartagees();
      // Le pull a pu RECRÉER des articles de catalogue manquants (pour qu'une
      // ligne de liste collaborative soit affichable). Le détail d'une liste
      // n'affiche QUE les lignes dont l'article existe au catalogue local
      // (articlesNotifierProvider) : sans réinvalider ce provider APRÈS le
      // pull, les articles fraîchement recréés restent invisibles et la liste
      // paraît vide alors que le widget en compte bien 39. On invalide donc le
      // catalogue (et catégories/rayons) une fois la recréation terminée.
      ref.invalidate(articlesNotifierProvider);
      ref.invalidate(categoriesNotifierProvider);
      ref.invalidate(rayonsNotifierProvider);
      ref.invalidate(articlesListeProvider);
      ref.invalidate(listesNotifierProvider);
    } catch (_) {
      // hors-ligne / non connecté : sans gravité, se refera au prochain retour.
    }
  }

  // Route l'ouverture depuis le widget : le bouton « Mode courses » envoie
  // action="mode_courses" et ouvre directement le mode courses ; sinon on
  // ouvre le détail de la liste (tap sur l'en-tête).
  Future<void> _ouvrirDepuisWidget(String action, String listeId) async {
    if (listeId.isEmpty) return;
    final listes = await ref.read(listesNotifierProvider.future);
    final liste = listes.where((l) => l.id == listeId).firstOrNull;
    if (liste == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => action == 'mode_courses'
          ? ModeCoursesScreen(liste: liste)
          : DetailListeScreen(liste: liste),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Démarre la synchro temps réel avec Firestore pour toute la durée
    // de vie de l'app (voir realtimeSyncProvider).
    ref.watch(realtimeSyncProvider);

    final afficherBudget = ref.watch(afficherBudgetProvider);
    final afficherRecettes = ref.watch(afficherRecettesProvider);
    final fondActif = ref.watch(fondActiveProvider);
    final fondOpacite = ref.watch(fondOpaciteProvider);

    void allerA(int index, int nbEcrans) {
      final cible = index.clamp(0, nbEcrans - 1);
      if (cible == _currentIndex) return;
      setState(() => _currentIndex = cible);
      _pageController.animateToPage(
        cible,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Un écran = une entrée de la barre de navigation. Recettes reste UNE
    // page (barre fixe + sous-onglets glissables) ; à ses bords, elle passe
    // le relais au défilement principal pour continuer vers l'écran voisin
    // (voir RecettesScreen.onDeborderGauche/Droite).
    final ecrans = <({NavigationDestination dest, Widget page})>[
      (
        dest: const NavigationDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart),
          label: 'Listes',
        ),
        page: const ListesScreen(),
      ),
      (
        dest: const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Catalogue',
        ),
        page: const CatalogueScreen(),
      ),
      if (afficherRecettes)
        (
          dest: const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Recettes',
          ),
          // Index de Recettes = 2 (Listes + Catalogue toujours avant).
          page: RecettesScreen(
            onDeborderGauche: () => allerA(1, _nbEcrans),
            onDeborderDroite: () => allerA(3, _nbEcrans),
          ),
        ),
      if (afficherBudget)
        (
          dest: const NavigationDestination(
            icon: Icon(Icons.euro_outlined),
            selectedIcon: Icon(Icons.euro),
            label: 'Budget',
          ),
          page: const BudgetScreen(),
        ),
      // Les statistiques ne sont plus un onglet : elles ont été fusionnées
      // dans l'écran Budget (une section « Statistiques » en bas).
      (
        dest: const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Réglages',
        ),
        page: const ParametresScreen(),
      ),
    ];

    _nbEcrans = ecrans.length;
    final safeIndex = _currentIndex.clamp(0, ecrans.length - 1);
    // Sur la page Recettes (index 2), on laisse le TabBarView interne capter
    // le glissement (sous-onglets + relais aux bords) en désactivant le
    // glissement principal ; le relais anime quand même la page via allerA.
    final surRecettes = afficherRecettes && safeIndex == 2;

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: surRecettes
                ? const NeverScrollableScrollPhysics()
                : null,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            children: [for (final e in ecrans) e.page],
          ),
          // Logo de fond — par dessus, non interactif
          if (fondActif)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: fondOpacite,
                  child: Center(
                    child: Image.asset(
                      'assets/background_icon.png',
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => allerA(i, ecrans.length),
        destinations: [for (final e in ecrans) e.dest],
      ),
    );
  }
}
